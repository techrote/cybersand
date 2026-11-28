#!/usr/bin/env python3
"""Read-only replay of exact captured c2 qualification, one ZIP arm at a time."""
import argparse
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output',type=Path)
args=parser.parse_args()
BASE=args.workspace_root.resolve()
ROOT=BASE/'evidence-c/final03-reader-root'
COMMIT='c2f8a73d34448bc1496ecd84bca02f0812c80d27'
TREE='351b947a50ce054361660eba9379006122527547'
ENGINE=BASE/'toolchain/godot47/Godot_v4.7-stable_linux.x86_64'
RAPIER=BASE/'cybersand-physics/godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so'
RUNTIMES=BASE/'evidence-root/final-03/linux/payload'
ARCHIVE=BASE/'evidence-root/final-03/graphical-linux/original.zip'
OUTPUT=args.output.resolve() if args.output else BASE/'evidence-c/final03-linux-complete-frozen-replay.json'
sys.path.insert(0,str(ROOT/'tools/pubpres_final'))
from run_comparison import driver_identity,verify_rapier
from replay_extent_check import verify_retained_runtime
from results import digest,need
from results_same_frame import reduce_receipt as reduce_original
from results_registered_mixed import reduce_receipt as reduce_mixed
from mixed_contract import verify_mixed_contract
from mixed_oracles import validate_mixed_workload
from deadline_contract import verify_deadline_contract,reduce_deadline_evidence,validate_deadline_cohort
from observer_support import validate_observers,calibration_measurements
from metrics import validate_slot_treatment,validate_deadline_baseline,supplementary_metrics
from run_focus import validate_requested_capture,observed_gap_counts,validate_complete_comparison
from run_source_abba import compare_registered_direction
from run_campaign import physical_outcome_parity

def sha(raw):return hashlib.sha256(raw).hexdigest()

@lru_cache(maxsize=1024)
def committed(source,name):
    return subprocess.check_output(['git','-C',str(ROOT),'show',source+':'+name])

OVERLAYS={
    'tests/pubpres003_causal_gameplay.gd':'tools/pubpres003/pubpres_causal_gameplay.gd',
    'tests/pubpres_final_gameplay.gd':'tools/pubpres_final/pubpres_final_gameplay.gd',
    'tests/pubpres_final_mixed_gameplay.gd':'tools/pubpres_final/pubpres_final_mixed_gameplay.gd',
    'tests/pubpres_final_mixed_registration.json':'tools/pubpres_final/mixed_registration.json',
    'tests/pubpres_final_deadline_gameplay.gd':'tools/pubpres_final/pubpres_final_deadline_gameplay.gd',
    'tests/pubpres_final_deadline_registration.json':'tools/pubpres_final/deadline_registration.json',
    'tests/pubpres_final_presentation_probe.gd':'tools/pubpres_final_observers/presentation_probe.gd',
}

def reconstruct(project,data,campaign,native):
    for resource,expected in data['source_identity']['files'].items():
        need(resource.startswith('res://'),'resource scheme')
        relative=resource.removeprefix('res://')
        need('..' not in Path(relative).parts and not Path(relative).is_absolute(),'resource path')
        if expected is None:continue
        target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
        if relative.endswith('/'+native.name):
            need(digest(native)==expected,'actual native bytes');os.link(native,target)
        elif relative.endswith('/'+RAPIER.name):
            need(digest(RAPIER)==expected,'actual Rapier bytes');os.link(RAPIER,target)
        else:
            if relative in campaign['overlay_sha256']:
                raw=committed(COMMIT,OVERLAYS.get(relative,'godot/'+relative))
            else:raw=committed(data['source_identity']['source_sha'],'godot/'+relative)
            need(sha(raw)==expected,'actual captured source/overlay bytes: '+relative)
            target.write_bytes(raw)

need(not OUTPUT.exists(),'preserve original replay output')
need(digest(ARCHIVE)=='afc128e3d90d952b3c801ba489d9ce66db51d10c7420094fb9f2096dbb20da71','exact archive')
driver=driver_identity()
need(driver['source_commit']==COMMIT and driver['source_tree']==TREE,'exact captured reader source')
need(digest(ENGINE)=='f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75','exact executable')
report={'schema':'pubpres-final03-linux-complete-frozen-replay-v1','application_source':COMMIT,'application_tree':TREE,
        'replay_program_sha256':digest(Path(__file__)),'archive_sha256':digest(ARCHIVE),
        'reader_source':driver,'native_runtimes':{},'comparisons':[],'failures':[],
        'original_graphical_job_conclusion':'SUCCESS','physical_acceptance':'HOLD',
        'scope':'Read-only exact captured code and raw-evidence replay. Same frozen V3 physical/native/terrain/actor/input/Water/current-GPU gates, separately registered mixed derivation, submitted geometry/pose/Follow/CPU and deadline evidence. Each transient arm is removed after analysis; original ZIP is unchanged. No Godot process is executed.'}

with zipfile.ZipFile(ARCHIVE) as z:
    summaries={name:json.loads(z.read(name)) for name in z.namelist() if name.endswith('/SUMMARY.json')}
    principal=summaries['source-abba/SUMMARY.json']
    for role,source in principal['sources'].items():
        verified=verify_retained_runtime(source,RUNTIMES/role,target_platform='linux')
        need(all(verified[key]==source['native_runtime'][key] for key in ['manifest_sha256','binary_sha256','source_inputs_sha256','toolchain','build_commit']),'full captured native provenance '+role)
        verify_rapier(ROOT,source,RAPIER)
        report['native_runtimes'][role]=verified
    need(report['native_runtimes']['C']['toolchain']==report['native_runtimes']['D']['toolchain'],'matched independently built native toolchains')
    for summary_name,s in summaries.items():
        if 'cases' not in s:continue
        name=summary_name.split('/')[0]
        need(s['complete'] is True and s['failures']==[] and s['driver']==driver,'original successful exact driver '+name)
        need(s['engine_sha256']==digest(ENGINE),'actual capture executable '+name)
        campaign_bytes=z.read(name+'/campaign.json');campaign=json.loads(campaign_bytes)
        need(sha(campaign_bytes)==s['campaign_sha256'],'actual campaign bytes')
        if name=='mixed-eight-actor':need(verify_mixed_contract(ROOT)==s['contract'],'unchanged registered mixed derivation')
        if name=='material-deadlines':need(verify_deadline_contract(ROOT)==s['contract'],'unchanged deadline derivation')
        group={'name':name,'original_summary_sha256':sha(z.read(summary_name)),'campaign_sha256':sha(campaign_bytes),'cases':[]}
        for case in s['cases']:
            items=[]
            scenario=next(x for x in campaign['cases'] if x['id']==case['case'])
            for arm in case.get('arms',[case]):
                if name=='mixed-eight-actor':folder=name+'/'+case['case']
                elif name=='material-deadlines':folder=name+'/'+case['case']+'/'+str(arm['index'])+'-deadline'+str(arm['requested_hz'])
                else:
                    role=arm['source_role'];slots=arm['slots']['requested_slots']
                    folder=name+'/'+case['case']+'/'+str(arm['index'])+'-'+role+'-slots'+str(slots)
                member=folder+'/receipt.json'
                try:
                    data=json.loads(z.read(member))
                    need(sha(z.read(member))==arm['receipt_sha256'],'original receipt SHA')
                    role='C' if data['source_identity']['source_sha']==COMMIT else 'D'
                    need(data['source_identity']['source_sha']==principal['sources'][role]['source_commit'],'exact registered source role')
                    with tempfile.TemporaryDirectory(prefix='pubpres-linux03-arm-',dir=BASE/'evidence-c') as temporary:
                        tmp=Path(temporary);project=tmp/'project';project.mkdir()
                        for n in z.namelist():
                            if n.startswith(folder+'/') and '/' not in n[len(folder)+1:] and not n.endswith('/'):
                                (tmp/Path(n).name).write_bytes(z.read(n))
                        receipt=tmp/'receipt.json';process=json.loads((tmp/'process.json').read_bytes());a=json.loads((tmp/'arm.json').read_bytes())
                        need(process['exit_code']==0 and process['timed_out'] is False and process['surviving_children_at_exit'] is False and process['interruption'] is None,'owned successful process')
                        need(process['source_commit']==data['source_identity']['source_sha'] and process['observed_application_pid']==data['process_id'] and process['app_sampler_pid_matched'] is True,'actual source/PID sampler')
                        need(process['display_owner_verified'] is True and digest(tmp/'display-owner.json')==process['display_owner_sha256'],'actual owned graphical surface receipt')
                        need(process['display_wrapper_sha256']==sha(committed(COMMIT,'tools/pubpres_playability_build/owned_xvfb.py')),'actual display helper source')
                        command=process['command'];args_start=command.index('--path')
                        need(command[args_start:]==a['arguments'],'actual command equals retained arm arguments')
                        need(command[args_start-1].endswith('/Godot_v4.7-stable_linux.x86_64'),'actual requested engine command')
                        need(not any('ERROR:' in (tmp/f).read_text(errors='replace') for f in ['stdout.log','stderr.log']),'strict raw diagnostics')
                        validate_requested_capture(data,scenario,campaign,data['source_identity']['source_sha'],a['nonce'],'opengl3')
                        reconstruct(project,data,campaign,Path(report['native_runtimes'][role]['binary_path']))
                        analysis=(reduce_mixed if name=='mixed-eight-actor' else reduce_original)(receipt,campaign,project,ENGINE,'C')
                        analysis['physical_gap_counts_above_ms']=observed_gap_counts(tmp/'receipt-events.jsonl',analysis['windows'],[100,250,500,1000])
                        events=[json.loads(line) for line in (tmp/'receipt-events.jsonl').read_text().splitlines()][1:]
                        enabled=arm['observers']['presentation_enabled']
                        observed=validate_observers(receipt,process,project,enabled)
                        need(observed==arm['observers'],'independent actual submitted pose/geometry/Follow/CPU reconstruction')
                        slots=validate_slot_treatment(data,events,2,require_status=name in ['mixed-eight-actor','material-deadlines'],expected_extent=campaign['fixtures'][scenario['fixture']]['extent'])
                        need(slots==arm['slots'],'slot authority reconstruction')
                        if name=='material-deadlines':
                            extra=reduce_deadline_evidence(receipt,events,arm['requested_hz'])
                            need(extra==arm['deadline'],'exact raw deadline status/age/counter reconstruction')
                        else:
                            extra=validate_deadline_baseline(data,required=role=='C')
                        if name=='mixed-eight-actor':
                            mixed=validate_mixed_workload(data,events,s['registration'])
                            need(mixed==arm['mixed'],'actual eight-actor/paint/contact proof reconstruction')
                            extra={'baseline_deadline':extra,'mixed':mixed}
                        # Full reduction result contains only its input receipt
                        # pathname as a relocatable field; preserve all others.
                        expected=dict(arm['statistics']);actual=dict(analysis)
                        for obj in (expected,actual):obj.pop('receipt',None)
                        # run_comparison attaches its additive baseline receipt.
                        if 'material_deadline_baseline' in expected:actual['material_deadline_baseline']=extra
                        need(actual==expected,'complete frozen statistics/gates reconstruction')
                        items.append({**arm,'statistics':analysis,'process':process,'observers':observed})
                        compact={'member':member,'receipt_sha256':sha(z.read(member)),'trace_sha256':data['trace_sha256'],
                                 'actual_source':data['source_identity']['source_sha'],'physical_windows':analysis['windows'],
                                 'observers':observed,'additional_evidence':extra,'all_frozen_gates_passed':True}
                        # Avoid a second copy of huge per-step Water/body arrays;
                        # exact equality above checked the complete original.
                        for w in compact['physical_windows'].values():
                            for k in list(w):
                                if k not in ['duration_seconds','completed_rapier_steps','rapier_steps_per_second','physical_gap_ms','post_draw_callback_gap_ms','first_attempt_input_to_physics_ms','consumed_input_to_physics_ms','native_tick_ms','main_callback_ms','rapier_solver_ms']:del w[k]
                        print('PASS',member,flush=True)
                except Exception as error:
                    report['failures'].append({'member':member,'reason':repr(error)})
                    compact={'member':member,'all_frozen_gates_passed':False,'reason':repr(error)}
                    print('FAILED',member,repr(error),flush=True)
                group.setdefault('arms',[]).append(compact)
            case_result={'case':case['case'],'replayed_arms':len(items)}
            if len(items)==len(case.get('arms',[case])):
                if name=='material-deadlines':
                    case_result['cohort']=validate_deadline_cohort(items,s['registration'])
                    need(case_result['cohort']==case['cohort'],'deadline complete cohort reconstruction')
                elif name!='mixed-eight-actor':
                    validate_complete_comparison(items,len(items))
                    parity=physical_outcome_parity(items)
                    need(parity==case['physical_outcome_parity'],'full equal-step physical outcomes')
                    case_result['physical_outcome_parity']=parity
                    if 'registered_direction' in case:
                        case_result['registered_direction']=compare_registered_direction(items)
                        need(case_result['registered_direction']==case['registered_direction'],'registered relative direction')
                    if 'observer_calibration' in case:
                        case_result['observer_calibration']=calibration_measurements(items)
                        need(case_result['observer_calibration']==case['observer_calibration'],'off/on/on/off calibration reconstruction')
            group['cases'].append(case_result)
        report['comparisons'].append(group)
        OUTPUT.write_text(json.dumps(report,indent=2)+'\n')
report['complete']=not report['failures'] and sum(len(c['arms']) for c in report['comparisons'])==47
OUTPUT.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'complete':report['complete'],'failures':report['failures'],'output':str(OUTPUT),'sha256':digest(OUTPUT)}))
