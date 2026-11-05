#!/usr/bin/env python3
"""Independent authored/material/workload audit; preserve every attempted coordinate."""
import argparse
from collections import Counter,defaultdict
import hashlib
import json
import math
from pathlib import Path
import struct
import la_physical_reduce as physical
import sol_active_normal_live_reduce as passive
import sol_active_normal_live_matrix as matrix
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path,value):path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))

def state_energy(state):
    vx,vy,omega=struct.unpack('<3d',bytes.fromhex(state['velocity_omega_f64le']))
    assert all(math.isfinite(v) for v in [vx,vy,omega,state['mass'],state['inertia']])
    value=.5*state['mass']*(vx*vx+vy*vy)+.5*state['inertia']*omega*omega
    assert math.isclose(value,state['kinetic'],rel_tol=1e-12,abs_tol=1e-9),'Scalar observer KE mismatch'
    return value

def application_audit(data,coordinate,allow_missing_worker_readback=False):
    owners={r['id']:r for r in data['initial_sample']['bodies']};count=len(owners)
    assert owners and set(owners)==set(range(1,count+1))
    previous={};records=[];max_error=0.;legacy_error=0.;configured=set()
    for step in data['steps']:
        index=step['step'];packet=step['native_response'];application=step['application']
        assert packet['valid'] and packet['response']=='LA-SELECTIVE' and packet['normal_policy']==coordinate['normal_policy'] and packet['normal_policy_locked']
        assert packet['session']==data['initial_sample']['session'] and packet['epoch']==data['initial_sample']['epoch'] and packet['sample_tick']==index
        if allow_missing_worker_readback and 'native_workers_configured' not in packet:pass
        else:
            assert packet['native_workers_configured']==packet['native_workers_constructed']==coordinate['workers']
            configured.add(packet['native_workers_configured'])
        rows={row['id']:row for row in packet['rows']};assert len(rows)==len(packet['rows'])==count and set(rows)==set(owners)
        assert application['accepted'] and not application['refusal'] and application['snapshot']==index+1 and application['application_variant']=='baseline'
        actions={a['id']:a for a in application['bodies']};assert len(actions)==len(application['bodies'])==count and set(actions)==set(owners)
        assert all(len(step[k])==count for k in ['before','sampled','live_before_application','after_application','after_step','external'])
        for identity,owner in owners.items():
            row=rows[identity];action=actions[identity];slot=identity-1
            assert row['normal_policy']==coordinate['normal_policy'] and row['instance_id']==owner['instance_id'] and row['generation']==owner['generation']
            assert row['budget']==owner['budget'] and row['proxy_count']==owner['count']
            assert 'refusal' not in action and action['instance_id']==row['instance_id'] and action['sample']==row['sample'] and action['age']==0
            if identity in previous:assert 0<(row['sample']-previous[identity])%1000000<500000
            previous[identity]=row['sample']
            states={k:step[k][slot] for k in ['before','sampled','live_before_application','after_application','after_step']}
            energies={k:state_energy(v) for k,v in states.items()}
            for state in states.values():legacy_error=max(legacy_error,abs(state['kinetic_legacy_f32_length_squared']-state['kinetic']))
            live=states['live_before_application'];after=states['after_application']
            vx,vy,omega=struct.unpack('<3d',bytes.fromhex(live['velocity_omega_f64le']))
            avx,avy,aomega=struct.unpack('<3d',bytes.fromhex(after['velocity_omega_f64le']))
            impulse=action['impulse'];correction=action['correction'];torque=action['torque']
            assert all(math.isfinite(v) for v in impulse+correction+[torque])
            predicted=[(0 if v*c<0 else v)+j/live['mass'] for v,c,j in zip([vx,vy],correction,impulse)]
            error=max(math.hypot(predicted[0]-avx,predicted[1]-avy),abs(omega+torque/live['inertia']-aomega))
            assert error<=1e-5,'Actual action/RID reconstruction failed';max_error=max(max_error,error)
            explicit=step['external'][slot]['impulse_work'];pre_native=energies['sampled']-energies['before']
            records.append(dict(step=index,body=identity,instance_id=row['instance_id'],generation=row['generation'],sample=row['sample'],
                explicit_api_work=explicit,pre_native_actuator_work=pre_native,controller_or_other_pre_native_work=pre_native-explicit,
                preapplication_work=energies['live_before_application']-energies['sampled'],
                actual_response_work=energies['after_application']-energies['live_before_application'],
                rapier_step_work=energies['after_step']-energies['after_application'],
                correction_potential_change=after['potential']-live['potential'],readback_error=error,
                actual_impulse=impulse,actual_torque=torque,actual_correction=correction))
    assert data['lifecycle'] and data['lifecycle'][1]['duplicate_owner_refused'] and data['lifecycle'][1]['native_unchanged'] and data['lifecycle'][1]['reset_coupling_retired']
    assert data['lifecycle'][-1]['accepted'] is False
    return dict(owner_count=count,maximum_RID_error=max_error,maximum_legacy_observer_KE_error=legacy_error,
        configured_workers=sorted(configured),configured_worker_observation='UNAVAILABLE in retained pilot001' if not configured else 'OBSERVED',records=records)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--allow-pilot-missing-worker-readback',action='store_true');args=parser.parse_args()
    folder=args.directory.resolve();output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();receipt_path=folder/'receipt.json';receipt=read(receipt_path)
    suite=receipt['matrix']['suite'];assert suite in ['authored','workload'] and receipt['post_source_equality']
    expected=matrix.coordinates(receipt);tags={(v['platform'],matrix.tag(v)):v for v in expected.values()};coverage=matrix.coverage(receipt)
    entries=[];groups=defaultdict(list)
    manifest=dict(evaluator='SOL-ACTIVE-NORMAL-LIVE-001-INDEPENDENT-AUTHORED',analysis_source=head,execution_source=receipt['identity']['source'],
        runtime_build_source=receipt['identity']['runtime_build_source'],input_receipt_sha256=sha(receipt_path),suite=suite,status='IN_PROGRESS',
        allow_pilot_missing_worker_readback=args.allow_pilot_missing_worker_readback,execution_coverage=coverage,results=entries)
    write(output/'manifest.json',manifest)
    for host,state in receipt['hosts'].items():
        for command in state['commands']:
            coordinate=tags.get((host,command['name']))
            if coordinate is None:continue
            name=host+'-'+command['name'];entry=dict(name=name,coordinate=coordinate,status='UNAVAILABLE',process_exit=command['exit']);entries.append(entry)
            try:
                assert command['clean'] and command.get('report_audit')=='PASS' and len(command.get('reports',[]))==1
                item=command['reports'][0];path=ROOT/item['path'];assert sha(path)==item['sha256'];data=read(path)
                assert data['source']==receipt['identity']['source'] and data['registration']=='SOL-ACTIVE-NORMAL-LIVE-001-AUTHORED'
                assert data['case']['id']==coordinate['case'] and data['arm']==data['native_mode']==coordinate['mode']=='LA-SELECTIVE'
                assert data['requested_workers']==coordinate['workers'] and data['repeat']==coordinate['repeat']
                steps=360 if data['case']['kind']=='static' else 180
                assert [s['step'] for s in data['steps']]==list(range(steps)) and not data['failures']
                result=physical.report(path);application=application_audit(data,coordinate,args.allow_pilot_missing_worker_readback)
                scalars=passive.scalar_audit({'steps':[dict(step=s['step'],response=s['native_response']) for s in data['steps']]},coordinate['normal_policy'])
                assert result['final'] is not None and result['material_source_ledger_closes']
                signature=matrix.digest(dict(initial_payload=data['initial_payload']['sha256'],geometry=data['initial_geometry'],
                    sample=data['initial_sample'],authored=data['authored'],case=data['case']))
                key=(host,coordinate['case'],coordinate['workers'],coordinate['repeat'])
                groups[key].append(dict(arm=coordinate['arm_id'],signature=signature,payload_sha256=data['initial_payload']['sha256']))
                observed=Counter(s['statistics']['values']['worker_threads_observed'] for s in data['steps']);stats=[s['statistics'] for s in data['steps']]
                summary={k:v for k,v in result.items() if k not in ['geometry_observations','energy']}
                summary.update(platform=host,registered_arm_id=coordinate['arm_id'],normal_policy=coordinate['normal_policy'],
                    configured_workers=application['configured_workers'],configured_worker_observation=application['configured_worker_observation'],
                    actual_worker_tick_distribution=dict(sorted(observed.items())),maximum_phase_jobs=max(v for s in stats for v in s['phase_jobs_last_tick']),
                    selected_arrivals=sum(s['arrival_count'] for s in scalars),arrival_missing=sum(s['arrival_missing'] for s in scalars),arrival_misaligned=sum(s['arrival_misaligned'] for s in scalars),
                    supported_arrival_witness='PASS' if sum(s['arrival_count'] for s in scalars)>0 else 'NO_OBSERVED_ARRIVALS',
                    passive_rejections=sum(s['passive_rejected'] for s in scalars),passive_energy_delta=sum(s['energy_delta'] for s in scalars),
                    maximum_scalar_observer_legacy_error=application['maximum_legacy_observer_KE_error'],maximum_actual_RID_error=application['maximum_RID_error'],
                    observed_legacy_wrench_f64=[sum(s['legacy_wrench_f64'][i] for s in scalars) for i in range(3)],
                    actual_response_work=sum(s['actual_response_work'] for s in application['records']),
                    explicit_api_work=sum(s['explicit_api_work'] for s in application['records']),controller_or_other_work=sum(s['controller_or_other_pre_native_work'] for s in application['records']),
                    preapplication_work=sum(s['preapplication_work'] for s in application['records']),rapier_step_work=sum(s['rapier_step_work'] for s in application['records']),
                    getter_mean_us=sum(s['native_response']['getter_us'] for s in data['steps'])/steps,
                    getter_max_us=max(s['native_response']['getter_us'] for s in data['steps']),
                    resident_cell_bytes_peak=max(s['statistics']['values']['resident_cell_bytes'] for s in data['steps']),
                    arrival_history_bytes_peak=max(s['native_response']['arrival_storage_bytes'] for s in data['steps']),
                    known_cell_plus_arrival_bytes_peak=max(s['statistics']['values']['resident_cell_bytes']+s['native_response']['arrival_storage_bytes'] for s in data['steps']),
                    process_seconds=command['seconds'],raw_path=item['path'],raw_sha256=item['sha256'],powered=data['case'].get('powered',False),
                    geometry_scope='Initial and sampled post-step material ROI; maximum convex-proxy depth, no five-boundary mask/union certification',
                    energy_scope='Observed scalar64 body work; Rapier step includes gravity/contact. Full grain/body conservation unavailable',
                    timing_scope='Full observer/instrumented shared-host profile; getter includes native solve/packet only; process/control costs separate')
                write(output/(name+'.json'),dict(summary=summary,geometry_observations=result['geometry_observations'],
                    native_scalar_accounting=scalars,actual_application_accounting=application['records']))
                entry.update(status='PASS',summary=summary,derivative_sha256=sha(output/(name+'.json')))
                print(name,'arrivals',summary['selected_arrivals'],'RID',summary['maximum_actual_RID_error'],flush=True)
            except Exception as error:entry.update(status='FAIL',error=type(error).__name__+': '+str(error));print(name,entry['error'],flush=True)
            write(output/'manifest.json',manifest)
    matched=matrix.common_inputs(groups,expected);manifest['common_initial_inputs']=matched
    complete=coverage['complete_requested_execution'] and len(entries)==len(expected) and all(e['status']=='PASS' for e in entries) and all(g['matched'] for g in matched)
    manifest['status']='COMPLETE' if complete else 'INCOMPLETE_OR_FAILED'
    manifest['full_registered_evidence_complete']=complete and coverage['requested_equals_full_registration'] and not args.allow_pilot_missing_worker_readback
    manifest['scope']='Coverage/application/material/observation accounting only; no original SOL authority or physical-clearance acceptance'
    assert head==p.git('rev-parse','HEAD').decode().strip();write(output/'manifest.json',manifest)
    return int(not complete)

if __name__=='__main__':raise SystemExit(main())
