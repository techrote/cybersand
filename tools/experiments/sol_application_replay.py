#!/usr/bin/env python3
"""Full recorded application accounting and algebraic alternatives; no live replay."""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import struct
import la_selective_experiment as p
import sol_active_normal_live_authored_reduce as audit
import sol_active_normal_live_reduce as native_audit

if not __debug__:raise RuntimeError('Recorded replay requires assertion checks')
ROOT=Path(__file__).resolve().parents[2]
REG=ROOT/'native/tests/fixtures/sol_application_replay_001.json'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))
def kinetic(vx,vy,omega,mass,inertia):return .5*mass*(vx*vx+vy*vy)+.5*inertia*omega*omega
def stages(vx,vy,omega,mass,inertia,impulse,torque,correction):
    assert mass>0 and inertia>0 and all(math.isfinite(v) for v in [vx,vy,omega,mass,inertia,torque]+impulse+correction)
    cx,cy=[0. if v*c<0 else v for v,c in zip([vx,vy],correction)]
    px,py,pw=cx+impulse[0]/mass,cy+impulse[1]/mass,omega+torque/inertia
    before=kinetic(vx,vy,omega,mass,inertia);clipped=kinetic(cx,cy,omega,mass,inertia)
    predicted=kinetic(px,py,pw,mass,inertia)
    return dict(live_KE=before,clip_only_KE=clipped,clip_work=clipped-before,
        predicted_after_recorded_action_KE=predicted,recorded_wrench_after_clip_work=predicted-clipped,
        predicted_combined_work=predicted-before,predicted_velocity=[px,py],predicted_omega=pw,
        alternative_retain_preclip_KE=kinetic(vx+impulse[0]/mass,vy+impulse[1]/mass,pw,mass,inertia))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();reg=read(REG)
    manifest_path=ROOT/'docs/audits/sol-active-normal-live-20261105/authored-full-reduction.json';manifest=read(manifest_path)
    assert manifest['status']=='COMPLETE' and manifest['execution_source']==reg['physical_execution_source']
    by_arm={};all_rows=[];summaries=[];initials=[]
    for arm in reg['arms']:
        name='windows-shared-granular-bodies-'+arm['id']+'-w1-r0'
        entry=next(e for e in manifest['results'] if e['name']==name);coordinate=entry['coordinate'];path=ROOT/entry['summary']['raw_path'].replace('\\','/')
        assert sha(path)==arm['raw_sha256']==entry['summary']['raw_sha256'];data=read(path)
        assert data['source']==reg['physical_execution_source'] and data['initial_payload']['sha256']==reg['common_initial_payload']
        assert [s['step'] for s in data['steps']]==list(range(180)) and not data['failures']
        initials.append({k:data[k] for k in ['initial_payload','initial_geometry','initial_sample','authored','case']})
        # Compare payload content identity, excluding apparatus path/timing metadata.
        initials[-1]['initial_payload']=data['initial_payload']['sha256']
        application=audit.application_audit(data,coordinate);assert application['owner_count']==3
        scalar=native_audit.scalar_audit({'steps':[dict(step=s['step'],response=s['native_response']) for s in data['steps']]},arm['normal_policy'])
        scalar_index={(s['step'],s['body']):s for s in scalar};work={(s['step'],s['body']):s for s in application['records']}
        rows=[];owners=defaultdict(list);previous={}
        for step in data['steps']:
            for slot,action in enumerate(step['application']['bodies']):
                body=action['id'];index=step['step'];native=next(r for r in step['native_response']['rows'] if r['id']==body)
                live=step['live_before_application'][slot];after=step['after_application'][slot]
                vx,vy,omega=struct.unpack('<3d',bytes.fromhex(live['velocity_omega_f64le']))
                avx,avy,aw=struct.unpack('<3d',bytes.fromhex(after['velocity_omega_f64le']))
                result=stages(vx,vy,omega,live['mass'],live['inertia'],action['impulse'],action['torque'],action['correction'])
                error=max(math.hypot(result['predicted_velocity'][0]-avx,result['predicted_velocity'][1]-avy),abs(result['predicted_omega']-aw));assert error<=1e-5
                native_torque=native['total_wrench_f64'][2]
                alt=stages(vx,vy,omega,live['mass'],live['inertia'],action['impulse'],native_torque,action['correction'])
                before_KE=audit.state_energy(step['before'][slot]);post_KE=audit.state_energy(step['after_step'][slot]);after_KE=audit.state_energy(after)
                ledger=work[(index,body)];scalar_row=scalar_index[(index,body)]
                row=dict(arm=arm['id'],step=index,body=body,**result,
                    live_velocity_omega=[vx,vy,omega],live_mass=live['mass'],live_inertia=live['inertia'],actual_action=action,
                    observed_before_KE=before_KE,observed_after_application_KE=after_KE,observed_after_step_KE=post_KE,
                    velocity_readback_error=error,actual_KE_rounding_residual=after_KE-result['predicted_after_recorded_action_KE'],
                    alternative_native_torque_afterclip_KE=alt['predicted_after_recorded_action_KE'],native_total_wrench_f64=native['total_wrench_f64'],
                    native_energy_prediction_gap=after_KE-native['passive_energy_after'],native_scalar=scalar_row,
                    correction_potential_change=ledger['correction_potential_change'],actual_response_work=ledger['actual_response_work'],
                    explicit_api_work=ledger['explicit_api_work'],controller_work=ledger['controller_or_other_pre_native_work'],preapplication_work=ledger['preapplication_work'],rapier_step_work=ledger['rapier_step_work'],
                    between_observation_work=before_KE-previous.get(body,before_KE))
                previous[body]=post_KE;rows.append(row);owners[body].append(row)
        assert len(rows)==540
        for body,values in owners.items():
            first,last=values[0],values[-1]
            sums={k:sum(v[k] for v in values) for k in ['clip_work','recorded_wrench_after_clip_work','actual_response_work','explicit_api_work','controller_work','preapplication_work','rapier_step_work','between_observation_work','correction_potential_change']}
            balance=first['observed_before_KE']+sum(sums[k] for k in ['actual_response_work','explicit_api_work','controller_work','preapplication_work','rapier_step_work','between_observation_work'])-last['observed_after_step_KE']
            summaries.append(dict(arm=arm['id'],body=body,steps=180,initial_KE=first['observed_before_KE'],final_KE=last['observed_after_step_KE'],**sums,work_balance_residual=balance,
                maximum_velocity_readback_error=max(v['velocity_readback_error'] for v in values),maximum_KE_rounding_residual=max(abs(v['actual_KE_rounding_residual']) for v in values),
                maximum_native_prediction_gap=max(v['native_energy_prediction_gap'] for v in values),
                positive_recorded_wrench_after_clip_steps=[v['step'] for v in values if v['recorded_wrench_after_clip_work']>0],
                positive_actual_application_steps=[v['step'] for v in values if v['actual_response_work']>0],
                correction_steps=[v['step'] for v in values if any(v['actual_action']['correction'])],
                selected_arrivals=sum(v['native_scalar']['arrival_count'] for v in values),
                endpoint=dict(nodes=last['native_scalar']['nodes'],application_work=last['actual_response_work'],rapier_step_work=last['rapier_step_work'])))
        by_arm[arm['id']]={(v['step'],v['body']):v for v in rows};all_rows+=rows
    assert initials[0]==initials[1] and len(all_rows)==1080
    first_divergences=[]
    original=by_arm['selective-original'];active=by_arm['selective-active']
    for body in [1,2,3]:
        differing=[i for i in range(180) if original[(i,body)]['native_scalar']['accepted_wrench_f64']!=active[(i,body)]['native_scalar']['accepted_wrench_f64']]
        index=differing[0] if differing else None
        first_divergences.append(dict(body=body,first_native_wrench_difference=index,
            exported_passive_state_equal=None if index is None else original[(index,body)]['native_scalar']['passive_state_f64']==active[(index,body)]['native_scalar']['passive_state_f64'],
            first_active_poststep_KE_greater=next((i for i in range(180) if active[(i,body)]['observed_after_step_KE']>original[(i,body)]['observed_after_step_KE']),None),
            original=None if index is None else original[(index,body)],active=None if index is None else active[(index,body)]))
    result=dict(registration=reg['registration'],analysis_source=head,physical_execution_source=reg['physical_execution_source'],runtime_build_source=reg['runtime_build_source'],registration_sha256=sha(REG),input_reduction_sha256=sha(manifest_path),raw_inputs=reg['arms'],
        observations=1080,body_steps_per_arm=540,common_initial_inputs=True,owner_summaries=summaries,first_divergences=first_divergences,
        live_actuation=False,native_mutations=0,rid_calls=0,generated_work=0,
        scope='Registered complete-window analysis of retained physical executions, not new trials. Alternatives are algebraic diagnostics, not applied trajectories or recovery predictions.',
        limitations='No per-node input/active-mask trace, unique trajectory-cause attribution, full grain/body energy conservation or original SOL admission. Native-torque substitution mixes recorded reference frames deliberately for diagnosis only.')
    write(output/'summary.json',result);write(output/'records.json',all_rows)
    assert head==p.git('rev-parse','HEAD').decode().strip();print(json.dumps(dict(observations=len(all_rows),first_divergences=[dict(body=v['body'],step=v['first_native_wrench_difference']) for v in first_divergences])))

if __name__=='__main__':main()
