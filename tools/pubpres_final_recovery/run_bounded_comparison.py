#!/usr/bin/env python3
"""Registered actual-progress stock/atomic0/4/4/0/stock comparisons, always HOLD."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

from identity import ROOT,HERE,driver_identity,digest
from retained_runtime import validate_runtime
from run_comparison import campaign_settings,prepare
from run_campaign import source_identity,copy_project,physical_outcome_parity
from run_focus import ENGINE_SHA256,selectors,observed_gap_counts,write_json
from results import canonical,need
from results_registered_renderer import reduce_receipt
from renderer_contract import verify_renderer_reducer
from run_renderer_comparison import strict_logs,validate_draw_identity
from run_source_abba import compare_registered_direction
from metrics import supplementary_metrics,validate_slot_treatment
from observer_support import (SELECTOR as PRESENTATION_SELECTOR,execute_with_resources,
                              validate_observers,calibration_measurements)
from requested_capture import validate_requested_renderer
from engine_trace import validate_files as validate_engine_trace
from qualification_gate import verify_bounded_inventory
import engine_admission

OBSERVER='tests/pubpres_recovery_gameplay.gd'
ORDER=[{'engine':'stock','render_thread':'safe','lookahead':0},
       {'engine':'bounded','render_thread':'separate','lookahead':0},
       {'engine':'bounded','render_thread':'separate','lookahead':4},
       {'engine':'bounded','render_thread':'separate','lookahead':4},
       {'engine':'bounded','render_thread':'separate','lookahead':0},
       {'engine':'stock','render_thread':'safe','lookahead':0}]


def validate_selectors(data,treatment,water,observed):
    atomic=treatment['engine']=='bounded'
    expected={'CYBERSAND_DIAG_ACTUAL_SUBMISSION':'1' if atomic else '0',
        'CYBERSAND_DIAG_WATER_COMPOSITION':str(water),
        'CYBERSAND_ENGINE_RENDER_LOOKAHEAD':str(treatment['lookahead']) if atomic else '',
        PRESENTATION_SELECTOR:'1' if observed else '0'}
    for phase in ('selectors_before','selectors_after'):
        value=data[phase]
        need(all(value['requested'].get(key)==wanted for key,wanted in expected.items()),'Requested recovery policy changed')
        need(value.get('actual_submission_observer_connected') is (atomic and observed),'Actual-submission observer did not execute selected state')
        state=value.get('actual_submission')
        need(isinstance(state,dict) and state.get('enabled') is atomic,'Actual atomic submission activation differs')
        if atomic:
            need(state.get('schema')=='pubpres-actual-submission-v1' and state.get('engine_atomic_admission') is True
                 and state.get('source_revision')==data['source_identity']['source_sha']
                 and type(state.get('committed_count')) is int and state['committed_count']>0,'Atomic callback did not actually admit draws')
    if atomic:
        need(data['selectors_after']['actual_submission']['committed_count']>data['selectors_before']['actual_submission']['committed_count'],
             'Atomic admission did not advance during real physical capture')


def validate_cohort(arms,registration,engines):
    need(len(arms)==6 and [row['index'] for row in arms]==list(range(6)),'Incomplete registered six-arm cohort')
    matches=[]
    for arm,treatment in zip(arms,ORDER):
        need(arm['treatment']==treatment,'Registered bounded order changed')
        match=dict(arm['statistics']['match'])
        need(match['engine']==digest(engines[treatment['engine']])
             and match['render_thread']=={'requested':treatment['render_thread'],'runtime':treatment['render_thread']},
             'Actual engine or rendering owner differs')
        del match['engine'],match['render_thread'];matches.append(match)
        need(arm['slots']['requested_slots']==2 and arm['slots']['effective_slots_verified'] is True
             and arm['statistics']['registered_material_treatment']=={'backend':'full','policy':''}
             and arm['statistics']['same_frame_continuation']['enabled'] is False,'Material or physics policy changed')
    need(all(canonical(value)==canonical(matches[0]) for value in matches),'Hardware, source workload or physics configuration differs')
    parity=physical_outcome_parity(arms)
    need(parity['same_source_pairs_equal'] is True,'Equal-step body or admitted input outcomes diverged; causal comparison refused')
    execution=all(arms[index]['engine_trace']['treatment_executed'] for index in (2,3))
    comparisons={}
    for name,indices in registration['comparisons'].items():
        subset=[dict(arms[index],index=order,arm='D' if order in (0,3) else 'C') for order,index in enumerate(indices)]
        result=compare_registered_direction(subset)
        comparisons[name]={'physical_direction':result,'treatment_executed':execution,
            'admissible_improvement':execution and result['repeatable_direction'],
            'disposition':'UNEXERCISED / HOLD' if not execution else result['disposition']}
    return {'physical_outcome_parity':parity,'registered_comparisons':comparisons,
            'actual_treatment_executed_in_both_candidate_captures':execution}


def product_gates(arms,registration):
    targets=registration['product_recovery_targets']; rows=[]
    controls=[arms[0],arms[5]]
    for index in (2,3):
        arm=arms[index];window=arm['statistics']['windows']['whole_capture'];physical=window['physical_gap_ms']
        observed_max=max(physical['max'],window['physical_no_step_prefix_ms'],window['physical_no_step_suffix_ms'])
        presentation=arm['observers']['presentation']['windows']['whole_capture']
        material=presentation['material_generation_age_at_submission_ms'];pose=presentation['verified_first_part_completion_age_ms']
        reasons=[]
        for name,value,limit in [('physical p95',physical['p95'],targets['physical_gap_p95_ms_max']),
                ('physical observed max including censored boundaries',observed_max,targets['physical_gap_max_ms_max']),
                ('material p95',None if not material else material['p95'],targets['material_generation_age_p95_ms_max']),
                ('material max',None if not material else material['max'],targets['material_generation_age_max_ms_max']),
                ('pose p95',None if not pose else pose['p95'],targets['visible_pose_completion_age_p95_ms_max']),
                ('pose max',None if not pose else pose['max'],targets['visible_pose_completion_age_max_ms_max'])]:
            if value is None or value>limit: reasons.append(name+' unavailable or above prospective limit')
        for field in ('material_generation_age_at_submission_ms','verified_first_part_completion_age_ms'):
            reference=[row['observers']['presentation']['windows']['whole_capture'][field] for row in controls]
            current=presentation[field]
            if not current or any(not value for value in reference) or any(current[key]>max(value[key] for value in reference) for key in ('p95','max')):
                reasons.append(field+' regressed against worse stock Safe reference or unavailable')
        withheld=presentation['withheld_body_submissions']/max(1,presentation['body_submissions'])
        reference=[row['observers']['presentation']['windows']['whole_capture'] for row in controls]
        if withheld>max(row['withheld_body_submissions']/max(1,row['body_submissions']) for row in reference):
            reasons.append('Actor withholding fraction regressed against stock Safe')
        # Process memory accounting deliberately includes setup and teardown;
        # it is not relabelled as capture-aligned resource usage.
        peak=arm['process'].get('sampled_peak_rss_bytes')
        control_peak=[row['process'].get('sampled_peak_rss_bytes') for row in controls]
        if peak is None or any(value is None for value in control_peak): reasons.append('Actual process peak RSS unavailable')
        elif peak>max(control_peak)*1.1+32*1024**2: reasons.append('Actual process peak RSS exceeds registered bound')
        rows.append({'index':index,'passed':not reasons,'reasons':reasons,'withheld_fraction':withheld,
                     'memory_scope':'Whole process actual Godot RSS including setup; not aligned to capture clocks.'})
    return {'rows':rows,'all_passed':all(row['passed'] for row in rows),'sustained_gate':'NOT_RUN / HOLD',
            'scope':'Additional prospective product targets. Relative performance alone does not select an architecture; five-minute gameplay/lifecycle remains required.'}



def verify_calibrations(paths,source,driver,engines,water,cases):
    need(len(paths)==2,'Both stock Safe and atomic4 require resulting-source off/on/on/off observer calibration')
    roles=set();result=[]
    for path in paths:
        path=Path(path).resolve();proof=json.loads(path.read_bytes());role=proof.get('calibration_engine')
        need(proof.get('schema')=='pubpres-recovery-bounded-comparison-v1' and proof.get('mode')=='observer-abba'
             and proof.get('complete') is True and proof.get('failures')==[] and proof.get('driver')==driver
             and proof['source']['source_commit']==source['source_commit'] and proof.get('water_composition')==water
             and role in ('stock','bounded') and role not in roles,'Observer calibration source, policy, engine or completeness differs')
        roles.add(role);available={row['case']:row for row in proof['cases']}
        need(set(cases)<=set(available),'Observer calibration omitted a requested workload')
        campaign=json.loads((path.parent/'campaign.json').read_bytes());project=path.parent/'template/project'
        for case in cases:
            rows=available[case]['arms'];need(len(rows)==4,'Observer calibration has missing original arms')
            for index,row in enumerate(rows):
                enabled=index in (1,2);expected=dict(ORDER[2] if role=='bounded' else ORDER[0],presentation_observer=enabled)
                need(row['index']==index and row['treatment']==expected,'Observer calibration treatment order differs')
                folder=path.parent/case/str(index);receipt=folder/'receipt.json'
                data=json.loads(receipt.read_bytes());process=json.loads((folder/'process.json').read_bytes())
                need(digest(receipt)==row['receipt_sha256'] and data['source_identity']['engine_sha256']==digest(engines[role]),
                     'Observer calibration actual receipt or engine differs')
                validate_selectors(data,expected,water,enabled)
                replay=reduce_receipt(receipt,campaign,project=project,engine=engines[role],arm_letter='C',expected_render_thread=expected['render_thread'])
                need(all(replay[key]==row['statistics'][key] for key in ('windows','first_144_body_trajectory_sha256','first_144_admitted_moves_sha256','trace_sha256')),
                     'Observer calibration complete physical oracle does not reproduce')
                need(validate_observers(receipt,process,project,enabled)==row['observers'], 'Raw presentation/CPU observer evidence does not reproduce')
                if role=='bounded':
                    need(validate_engine_trace(folder,data,thread='separate',budget=4,presentation_enabled=enabled)==row['engine_trace'],
                         'Raw calibration actual application/engine join does not reproduce')
            need(calibration_measurements(rows)==available[case]['observer_calibration'],'Original off/on overhead analysis changed')
        result.append({'path':str(path),'sha256':digest(path),'role':role,'original_raw_physical_and_observer_replayed':True})
    need(roles=={'stock','bounded'},'Observer calibration must cover both actual submission paths')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT)
    for name in ('runtime','stock-engine','output'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--correctness-inventory',type=Path)
    parser.add_argument('--mode',choices=('cohort','observer-abba'),default='cohort')
    parser.add_argument('--calibration-engine',choices=('stock','bounded'),default='bounded')
    parser.add_argument('--observer-calibration',type=Path,action='append')
    parser.add_argument('--case',action='append',required=True)
    parser.add_argument('--water-composition',type=int,choices=(0,1),default=0)
    parser.add_argument('--display-wrapper',type=Path)
    parser.add_argument('--development-engine',type=Path)
    parser.add_argument('--development-engine-proof',type=Path)
    parser.add_argument('--development-gates',type=Path)
    parser.add_argument('--external-display-record',type=Path)
    engine_admission.add_arguments(parser)
    args=parser.parse_args()
    need(not any(key.startswith('WB_COMBINED_') for key in os.environ),'Inherited unregistered Workbench treatment')
    output=args.output.resolve();need(not output.exists(),'Preserve all earlier attempts')
    source_root=args.source.resolve();source=source_identity(source_root);driver=driver_identity()
    need(source['source_commit']==driver['source_commit'] and source['source_tree']==driver['source_tree'],
         'Actual candidate and driver must be exact resulting source')
    source['native_runtime']=validate_runtime(source_root,source,args.runtime.resolve(),False)
    registered=json.loads((HERE/'registration.json').read_bytes())
    need(registered['order']==ORDER and registered['minimum_real_steps']==144
         and registered['minimum_capture_usec']==10000000 and registered['maximum_capture_usec']==90000000,
         'Prospective physical comparison registration differs')
    base=json.loads((ROOT/'tools/pubpres_final/registration.json').read_bytes())
    campaign=campaign_settings(base,args.case,False)
    platform='windows' if os.name=='nt' else 'linux'; backend='opengl3_angle' if platform=='windows' else 'opengl3'
    stock=args.stock_engine.resolve();need(digest(stock)==ENGINE_SHA256[platform],'Official stock control bytes differ')
    if args.development_engine:
        need(args.engine_payload is None and args.development_engine_proof and args.development_gates,
             'Supply complete explicit local-development engine/gates; never mix payload roles')
        from development_engine import admit
        custom=args.development_engine.resolve()
        build=admit(custom,args.development_engine_proof,args.development_gates,source,args.water_composition)
        prerequisite={'development_only':True,'actual_graphical_gates':build['verified']}
    else:
        need(os.name=='nt' and args.correctness_inventory,'Qualified comparison requires Windows engine payload and hosted integration inventory')
        custom,build=engine_admission.admit(args)
        prerequisite=verify_bounded_inventory(args.correctness_inventory,source,driver,stock,custom,args.water_composition)
    external=None
    if args.external_display_record:
        need(args.development_engine is not None and args.display_wrapper is None,'External local display record is development-only')
        external=json.loads(args.external_display_record.read_bytes())
        need(external.get('display')==os.environ.get('DISPLAY') and external.get('dbus_session_bus_address')==os.environ.get('DBUS_SESSION_BUS_ADDRESS'),
             'Local display/DBus condition differs from matched record')
    campaign['overlay_sha256'][OBSERVER]=digest(HERE/'pubpres_recovery_gameplay.gd')
    campaign['observer_entrypoint']=OBSERVER
    engines={'stock':stock,'bounded':custom}
    order=ORDER if args.mode=='cohort' else [dict(ORDER[2] if args.calibration_engine=='bounded' else ORDER[0],presentation_observer=value) for value in (False,True,True,False)]
    output.mkdir(parents=True);write_json(output/'campaign.json',campaign)
    report={'schema':'pubpres-recovery-bounded-comparison-v1','source':source,'driver':driver,'registration':registered,
        'registration_sha256':digest(HERE/'registration.json'),'reducer':verify_renderer_reducer(ROOT),
        'engine_admission':build,'prerequisites':prerequisite,'external_display':external,'mode':args.mode,
        'water_composition':args.water_composition,'calibration_engine':args.calibration_engine if args.mode=='observer-abba' else None,'order':order,'cases':[],'failures':[],'complete':False,
        'physical_acceptance':'HOLD','scope':'Actual physical progression with matched source/native/scene/input/render ownership; CPU draw completion is not GPU/display completion. No automatic selection or default activation.'}
    def save():write_json(output/'SUMMARY.json',report)
    save()
    if args.mode=='cohort':
        report['observer_calibration']=verify_calibrations(args.observer_calibration or [],source,driver,engines,args.water_composition,args.case)
        save()
    # The actual official editor imports source once. A local template runtime
    # has no editor import command; it subsequently executes the same immutable
    # imported source. No binary substitution or copied physical receipt occurs.
    template=prepare(source_root,source,output/'template',campaign,stock,None,
                     overlay_sources={OBSERVER:HERE/'pubpres_recovery_gameplay.gd'})
    strict_logs(output/'template/import')
    for case in campaign['cases']:
        arms=[]
        for index,treatment in enumerate(order):
            thread=treatment['render_thread'];engine=engines[treatment['engine']]
            folder=output/case['id']/str(index);folder.mkdir(parents=True)
            project=output/'projects'/(case['id']+'-'+str(index));project.parent.mkdir(parents=True,exist_ok=True)
            copy_project(template,project,imported=True)
            nonce=uuid.uuid4().hex;receipt=folder/'receipt.json';observed=treatment.get('presentation_observer',True)
            settings=selectors({'material':'full','same_frame_continuation':False,'wave_column_probe':False,'causal':False},nonce)
            settings.update(CYBERSAND_DIAG_FULL_IMAGE_SLOTS='2',CYBERSAND_PLAYABILITY_RENDER_THREAD=thread,
                CYBERSAND_MATERIAL_QUEUE_THREAD=thread,CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ='0',
                CYBERSAND_DIAG_MATERIAL_STEP_INTERVAL='0',CYBERSAND_DIAG_ACTUAL_SUBMISSION='1' if treatment['engine']=='bounded' else '0',
                CYBERSAND_DIAG_WATER_COMPOSITION=str(args.water_composition),
                CYBERSAND_ENGINE_RENDER_LOOKAHEAD=str(treatment['lookahead']) if treatment['engine']=='bounded' else '',
                CYBERSAND_ENGINE_RENDER_LOOKAHEAD_TRACE=str(folder/'engine-draws.json') if treatment['engine']=='bounded' else '')
            settings[PRESENTATION_SELECTOR]='1' if observed else '0'
            arguments=['--path',str(project),'--rendering-method','gl_compatibility','--rendering-driver',backend,
                '--render-thread',thread,'--audio-driver','Dummy','--log-file',str(folder/'godot.log'),'--script','res://'+OBSERVER,'--',
                '--receipt='+str(receipt),'--fixture='+case['fixture'],'--camera='+case['camera'],'--workers='+str(case['workers']),
                '--water-law='+case['water_law'],'--water-variant='+case.get('water_variant','reference'),
                '--water-profile='+case.get('water_profile',campaign['measurement']['water_profile']),
                '--input-mode='+case.get('input_mode','tape'),'--command-mode=repeated_callback','--observer-mode=full']
            write_json(folder/'arm.json',{'source':source,'scenario':case,'nonce':nonce,'treatment':treatment,
                'engine_sha256':digest(engine),'selectors':settings,'arguments':arguments})
            print(case['id'],index,treatment,flush=True)
            try:
                process=execute_with_resources(engine,arguments,folder,source['source_commit'],settings,420,args.display_wrapper)
                strict_logs(folder);data=json.loads(receipt.read_bytes())
                validate_requested_renderer(data,case,campaign,source['source_commit'],nonce,digest(engine),thread,expected_driver=backend)
                validate_selectors(data,treatment,args.water_composition,observed)
                analysis=reduce_receipt(receipt,campaign,project=project,engine=engine,arm_letter='C',expected_render_thread=thread)
                observers=validate_observers(receipt,process,project,observed)
                events=[json.loads(line) for line in receipt.with_name('receipt-events.jsonl').read_text().splitlines()]
                validate_draw_identity(events,thread)
                slots=validate_slot_treatment(data,events,2,True,expected_extent=campaign['fixtures'][case['fixture']]['extent'])
                analysis['physical_gap_counts_above_ms']=observed_gap_counts(receipt.with_name('receipt-events.jsonl'),analysis['windows'],base['reported_gap_thresholds_ms'])
                supplement=supplementary_metrics(receipt)
                need(thread!='separate' or all(not value['material_draw_identity_available'] for value in supplement['windows'].values()),
                     'Deferred notification was relabelled as live uploaded material')
                need(process['observed_application_pid']==data['process_id'],'Actual process PID differs')
                process['app_sampler_pid_matched']=True
                write_json(folder/'process.json',process)
                engine_trace=validate_engine_trace(folder,data,thread=thread,budget=treatment['lookahead'],presentation_enabled=observed) \
                    if treatment['engine']=='bounded' else None
                arm={'arm':'C','index':index,'treatment':treatment,'statistics':analysis,'slots':slots,
                    'supplementary':supplement,'process':process,'observers':observers,'engine_trace':engine_trace,
                    'receipt_sha256':digest(receipt)}
                arms.append(arm);write_json(folder/'analysis.json',arm)
                shutil.rmtree(project)
            except Exception as error:
                report['failures'].append({'case':case['id'],'index':index,'treatment':treatment,'reason':str(error)})
            save()
        result={'case':case['id'],'arms':arms}
        try:
            if args.mode=='cohort':
                result.update(validate_cohort(arms,registered,engines));result['product_targets']=product_gates(arms,registered)
            else:
                result['observer_calibration']=calibration_measurements(arms)
                result['physical_outcome_parity']=physical_outcome_parity(arms)
                need(result['physical_outcome_parity']['same_source_pairs_equal'] is True,'Observer control changed equal-step physical outcomes')
        except Exception as error:report['failures'].append({'case':case['id'],'reason':str(error)})
        report['cases'].append(result);save()
    report['complete']=not report['failures'];save()
    print(json.dumps({'complete':report['complete'],'cases':len(report['cases']),'failures':report['failures'],'physical_acceptance':'HOLD'}))
    return 0 if report['complete'] else 1

if __name__=='__main__':sys.exit(main())
