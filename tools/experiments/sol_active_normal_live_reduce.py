#!/usr/bin/env python3
"""Independent chamber geometry/tuple/application audit plus scalar64 passive accounting."""
import argparse
import json
import math
import sol_active_normal_live_matrix as matrix
from pathlib import Path
import sol_chamber_reduce as geometry
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]

def energy(state,wrench):
    vx,vy,_,_,omega,mass,inertia,_=state
    x,y,torque=wrench
    return .5*mass*((vx+x/mass)**2+(vy+y/mass)**2)+.5*inertia*(omega+torque/inertia)**2

def scalar_audit(data,policy):
    rows=[]
    for step in data['steps']:
        packet=step['response'];assert packet['normal_policy']==policy and packet['normal_policy_locked']
        for row in packet['rows']:
            assert row['normal_policy']==policy
            state=row['passive_state_f64'];raw=row['passive_raw_wrench_f64'];accepted=row['passive_accepted_wrench_f64']
            assert len(state)==8 and len(raw)==len(accepted)==3 and all(math.isfinite(v) for v in state+raw+accepted)
            before=energy(state,[0,0,0]);after=energy(state,accepted);raw_after=energy(state,raw)
            assert math.isclose(before,row['passive_energy_before'],rel_tol=1e-12,abs_tol=1e-9)
            assert math.isclose(after,row['passive_energy_after'],rel_tol=1e-12,abs_tol=1e-9)
            rejected=not math.isfinite(raw_after) or raw_after>before+1e-6*max(1,before)
            assert rejected==row['passivity_rejected']
            if rejected:assert accepted==[0,0,0] and row['passive_scale']==0
            else:assert raw==accepted and row['passive_scale']==1
            assert after<=before+1e-6*max(1,before)
            assert row['updates']==row['nodes']*8 and row['nodes']<=1024
            rows.append(dict(step=step['step'],body=row['id'],normal_policy=policy,
                passive_state_f64=state,raw_wrench_f64=raw,accepted_wrench_f64=accepted,
                legacy_wrench_f64=row['legacy_wrench_f64'],total_wrench_f64=row['total_wrench_f64'],
                energy_before=before,energy_after=after,raw_energy_after=raw_after,energy_delta=after-before,
                passive_rejected=rejected,normal_capacity=row['normal_capacity'],normal_raw=row['normal_raw'],
                normal_accepted=row['normal_accepted'],tangent_raw=row['tangent_raw'],tangent_accepted=row['tangent_accepted'],
                normal_cap_hits=row['normal_cap_hits'],tangent_cap_hits=row['tangent_cap_hits'],nodes=row['nodes'],bins=row['bins'],
                updates=row['updates'],quadrature_clamps=row['quadrature_clamps'],arrival_count=row['arrival_count'],
                arrival_missing=row['arrival_missing'],arrival_misaligned=row['arrival_misaligned'],getter_us=packet['getter_us']))
    return rows

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path);args=parser.parse_args()
    folder=args.directory.resolve();output=(args.output or folder/'independent-reduction').resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();receipt_path=folder/'receipt.json';receipt=json.loads(receipt_path.read_text(encoding='utf-8'))
    assert receipt['matrix']['suite']=='chamber' and receipt['post_source_equality']
    profile=json.loads((ROOT/'godot/tests/fixtures/sol_chamber/registration.json').read_text(encoding='utf-8'));rows=[];groups={}
    coverage=matrix.coverage(receipt);expected=matrix.coordinates(receipt);tags={(v['platform'],matrix.tag(v)):v for v in expected.values()}
    manifest=dict(evaluator='SOL-ACTIVE-NORMAL-LIVE-001-INDEPENDENT-CHAMBER',status='IN_PROGRESS',analysis_source=head,
        execution_source=receipt['identity']['source'],runtime_build_source=receipt['identity']['runtime_build_source'],
        input_receipt_sha256=p.sha(receipt_path.read_bytes()),execution_coverage=coverage,
        source_sha256={n:p.sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n')) for n in
        ['tools/experiments/sol_active_normal_live_reduce.py','tools/experiments/sol_active_normal_live_matrix.py','tools/experiments/sol_chamber_reduce.py','tools/experiments/la_physical_reduce.py']},results=rows)
    p.write(output/'manifest.json',manifest)
    for platform,host in receipt['hosts'].items():
        for process in host['commands']:
            coordinate=tags.get((platform,process['name']))
            if coordinate is None:continue
            name=platform+'-'+process['name'];entry=dict(name=name,coordinate=coordinate,status='UNAVAILABLE',process_exit=process['exit'])
            rows.append(entry)
            try:
                assert process['clean'] and process.get('report_audit')=='PASS' and len(process.get('reports',[]))==1,'Failed attempted episode/report audit'
                item=process['reports'][0];path=ROOT/item['path'];assert p.sha(path.read_bytes())==item['sha256']
                data=json.loads(path.read_text(encoding='utf-8'));policy=data['normal_policy'];matrix.bind(data,coordinate,receipt['identity']['source'])
                result=geometry.report(path,profile)
                assert result['complete_episode'] and result['valid_initial_geometry'] and result['exact_tuple_multiset_conservation']
                signature=matrix.initial_signature(data,result);key=(platform,coordinate['case'],coordinate['workers'],coordinate['repeat'])
                groups.setdefault(key,[]).append(dict(arm=coordinate['arm_id'],signature=signature,payload_sha256=result['initial_payload']['sha256']))
                scalar=scalar_audit(data,policy);getter=[r['getter_us'] for r in scalar]
                summary={k:v for k,v in result.items() if k not in ['steps','initial_payload','final_payload']}
                selective=data['mode']=='LA-SELECTIVE'
                summary.update(platform=platform,registered_arm_id=coordinate['arm_id'],normal_policy=policy,raw_path=item['path'],raw_sha256=item['sha256'],
                    getter_mean_us=sum(getter)/len(getter),getter_max_us=max(getter),passive_rejections=sum(r['passive_rejected'] for r in scalar),
                    passive_energy_delta_sum=sum(r['energy_delta'] for r in scalar),maximum_nodes=max(r['nodes'] for r in scalar),
                    selected_arrivals=sum(r['arrival_count'] for r in scalar) if selective else None,
                    arrival_channel_raw_counter_sum=sum(r['arrival_count'] for r in scalar),
                    arrival_qualifier='Observed one-use selected arrivals; missing counts retain unstamped blocked attempts' if selective else 'UNAVAILABLE: arrival-history instrumentation disabled for this response; raw zero counters are not observed absence of arrivals',
                    strict_all_observations_clear=result['maximum_observed_sand_area']<=1e-6 and result['maximum_observed_sand_depth']<=2e-5,
                    nonembedded_depth_screen=result['maximum_observed_sand_depth']<=1,
                    recovery_scope='Descriptive full-window chamber checks only; no original SOL evaluator/120+60 admission')
                p.write(output/(name+'.json'),dict(summary=summary,steps=result['steps'],scalar_accounting=scalar))
                entry.update(status='PASS',summary=summary,derivative_sha256=p.sha((output/(name+'.json')).read_bytes()))
                print(name,summary['maximum_observed_sand_area'],summary['maximum_observed_sand_depth'],flush=True)
            except Exception as error:
                entry.update(status='FAIL',error=type(error).__name__+': '+str(error));print(name,entry['error'],flush=True)
            p.write(output/'manifest.json',manifest)
    assert head==p.git('rev-parse','HEAD').decode().strip(),'Evaluator source changed'
    matched=matrix.common_inputs(groups,expected);manifest['common_initial_inputs']=matched
    complete=coverage['complete_requested_execution'] and len(rows)==len(expected) and all(e['status']=='PASS' for e in rows) and all(g['matched'] for g in matched)
    manifest['status']='COMPLETE' if complete else 'INCOMPLETE_OR_FAILED'
    manifest['completion_scope']='Coverage and independent observation reconstruction only; physical clearance is a separate metric'
    manifest['full_registered_chamber_evidence_complete']=complete and coverage['requested_equals_full_registration']
    manifest['original_SOL_clearance']='NO-GO; surrogate only, no original authority or recurrence-clock admission'
    p.write(output/'manifest.json',manifest)
    return int(not complete)

if __name__=='__main__':raise SystemExit(main())
