#!/usr/bin/env python3
"""Curate structured receipts and compact smoke ledgers; never copy raw logs/binaries."""
import argparse
import copy
import json
from pathlib import Path
import la_selective_experiment as p
import sol_active_normal_live_runtime as runtime

ROOT=runtime.ROOT
RUN=ROOT/'build/sol-active-normal-live'

def read(path):return json.loads(path.read_text(encoding='utf-8'))

def reference(output):
    assert not p.git('status','--porcelain'),'Commit curator before exporting reference'
    source=RUN/'chamber-smoke-001/windows/closed-driven-selective-active-w1-r0/closed-driven-LA-SELECTIVE-w1-r0.json'
    data=read(source);assert data['normal_policy']=='active-normal-001' and data['live_registration']=='SOL-ACTIVE-NORMAL-LIVE-001'
    target=output/'raw-reference-closed-driven-active.json';manifest=output/'raw-reference-custody.json'
    assert output.is_dir() and not target.exists() and not manifest.exists()
    target.write_bytes(source.read_bytes());assert runtime.sha(target)==runtime.sha(source)
    p.write(manifest,dict(curation_source=p.git('rev-parse','HEAD').decode().strip(),curator_sha256=runtime.lfsha(Path(__file__)),
        source_path=str(source.relative_to(ROOT)),public_file=target.name,sha256=runtime.sha(target),bytes=target.stat().st_size,
        execution_source=data['source'],scope='Exact raw structured Windows candidate report; all five material/mask censuses per step, no original SOL authority',
        matched_original_reference='docs/audits/sol-chamber-20261105/raw-reference-closed-driven-selective.json',
        matched_original_sha256='a7dd38910f39f672e48e1057edaedb0ed30a90cd53ba3f3d66950558d688ee33'))
    print('Exported exact structured candidate reference',target.stat().st_size,runtime.sha(target))

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('output',type=Path);parser.add_argument('--reference-only',action='store_true');args=parser.parse_args()
    output=args.output.resolve();assert output.is_relative_to(ROOT/'docs/audits')
    if args.reference_only:return reference(output)
    assert not output.exists()
    assert not p.git('status','--porcelain'),'Commit curator before generating review evidence'
    identity=runtime.identity();output.mkdir(parents=True)
    inputs={};files={}
    def load(path):inputs[str(path.relative_to(ROOT))]=runtime.sha(path);return read(path)
    def save(name,data):p.write(output/name,data);files[name]=runtime.sha(output/name)
    build=load(runtime.OUTPUT/'receipt.json');save('build.json',build)
    for platform,host in build['platforms'].items():
        before=next(c for c in host['commands'] if c['name']=='dependencies-before')
        after=next(c for c in host['commands'] if c['name']=='dependencies-after')
        raw=load(ROOT/before['log']);assert raw==load(ROOT/after['log'])
        if platform=='windows':
            sdk=host['toolchain']['sdk'].replace('\\','/')
            compiler=host['toolchain']['compiler'].replace('\\','/');toolchain=compiler.rsplit('/',2)[0]
            prefixes=[(sdk,'godot-cpp'),(toolchain,'llvm-mingw')]
        else:
            sdk=host['toolchain']['library']['path'].split('/bin/',1)[0]
            prefixes=[(sdk,'godot-cpp'),(p.wsl_path(ROOT),'owned-source')]
        normalized={}
        for key,value in raw.items():
            name=key.replace('\\','/')
            for prefix,label in prefixes:
                if name.startswith(prefix+'/'):name=label+name[len(prefix):];break
            else:name='host/'+name.lstrip('/')
            assert name not in normalized;normalized[name]=value
        save('dependencies-'+platform+'.json',dict(scope='Normalized path IDs; raw before/after log hashes remain in build receipt',files=normalized))
    values=load(RUN/'values-001/receipt.json')
    for row in values['executions']:
        row['case_count']=len(row.pop('cases'));assert row['case_count']==38 and row['frozen_physical_parity']=='PASS'
    save('values.json',values)
    save('native.json',load(RUN/'native-001/receipt.json'))
    save('policy.json',load(RUN/'policy-002/receipt.json'))
    save('policy-observations.json',{h:load(RUN/f'policy-002/{h}/policy.json') for h in ['windows','linux']})
    save('scoped.json',load(RUN/'scoped-001/receipt.json'))
    execution=load(RUN/'chamber-smoke-001/receipt.json');save('smoke-execution.json',execution)
    reduction=load(RUN/'chamber-smoke-001/independent-reduction/manifest.json')
    assert reduction['status']=='COMPLETE' and len(reduction['results'])==8
    cases=[];summaries=[]
    boundary_columns=['step','boundary','native_tick','revision','world_instance','rid','pose_f64le','velocity_omega_f64le',
        'sand_area','sand_max_depth','area_by_material','hard_exclusions','complete_in_fixed_roi',
        'body_center_cells','actual_mask_cells','centre_mask_symmetric_difference','sand_cells_under_actual_mask']
    work_columns=['step','force','before_velocity_omega_f64le','after_external_velocity_omega_f64le',
        'live_before_velocity_omega_f64le','after_application_velocity_omega_f64le','after_step_velocity_omega_f64le',
        'external_api_kinetic_delta','candidate_kinetic_delta','rapier_kinetic_delta','preapplication_kinetic_delta',
        'actual_packet_impulse','actual_packet_torque','correction']
    for row in reduction['results']:
        name=row['name'];derivative=load(RUN/'chamber-smoke-001/independent-reduction'/(name+'.json'))
        data=load(ROOT/derivative['summary']['raw_path']);scalar=derivative['scalar_accounting'];summary=copy.deepcopy(derivative['summary'])
        summary['arrival_qualifier']='Observed one-use selected arrivals; missing counts retain blocked attempts without valid prior transport. Counts differ with resulting trajectories.'
        sums=summary['wrench_component_sums']
        for axis in ['x','y']:sums['rounded_vector_subtraction_residual_'+axis]=sums.pop('legacy_residual_'+axis)
        summary['observed_legacy_wrench_sum_f64']=[sum(s['legacy_wrench_f64'][i] for s in scalar) for i in range(3)]
        summary['correction_max_norm']=max(sum(v*v for v in s['response']['rows'][0]['correction'])**.5 for s in data['steps'])
        summaries.append(dict(name=name,**summary));boundaries=[];work=[]
        for source_step,reduced_step in zip(data['steps'],derivative['steps']):
            assert source_step['step']==reduced_step['step']
            for capture,measure in zip(source_step['boundaries'],reduced_step['geometry']):
                fields=dict(step=source_step['step'],boundary=capture['boundary'],native_tick=capture['native_tick'],revision=capture['revision'],world_instance=capture['world_instance'],rid=capture['state']['rid'],
                    pose_f64le=capture['state']['pose_f64le'],velocity_omega_f64le=capture['state']['velocity_omega_f64le'],**{k:measure[k] for k in boundary_columns[8:]})
                boundaries.append([fields[k] for k in boundary_columns])
            states=[source_step[k]['velocity_omega_f64le'] for k in ['before','after_external_drive','live_before_application','after_application','after_step']]
            response=source_step['response']['rows'][0]
            work.append([source_step['step'],source_step['force'],*states,*[source_step[k] for k in work_columns[7:11]],response['impulse'],response['torque'],response['correction']])
        scalar_columns=list(scalar[0]);assert len(boundaries)==900 and len(work)==len(scalar)==180
        cases.append(dict(name=name,raw_report_sha256=summary['raw_sha256'],geometry_f64le=data['geometry_f64le'],actual_shapes=data['actual_shapes'],
            mass=data['initial']['state']['mass'],inertia=data['initial']['state']['inertia'],initial_sample=data['initial_sample'],
            native_identity_columns=['step','session','epoch','sample_tick','row_id','instance_id','generation','sample','proxy_count'],
            native_identity_rows=[[s['step'],s['response']['session'],s['response']['epoch'],s['response']['sample_tick'],*[s['response']['rows'][0][k] for k in ['id','instance_id','generation','sample','proxy_count']]] for s in data['steps']],
            boundary_columns=boundary_columns,boundaries=boundaries,
            work_columns=work_columns,work=work,scalar_columns=scalar_columns,scalar_rows=[[s[k] for k in scalar_columns] for s in scalar]))
    save('smoke-summary.json',dict(scope='Eight-episode smoke reduction complete; registered240-episode chamber matrix not complete',
        analysis_source=reduction['analysis_source'],execution_source=reduction['execution_source'],runtime_build_source=reduction['runtime_build_source'],results=summaries))
    save('smoke-steps.json',dict(scope='All1440steps/7200boundaries. Reconstruct recorded proxy union from pose_f64le and case geometry_f64le; full per-cell census remains raw locally.',
        batch_trace='UNAVAILABLE in live packets; source parity/value-phase trace is separate',cases=cases))
    checks=load(RUN/'checkpoint-001/receipt.json')
    checks['additional_commands']=[load(RUN/'checkpoint-001'/n) for n in ['repository-default.receipt.json','historical-source-refusal.receipt.json']]
    save('validation.json',checks)
    save('manifest.json',dict(schema='cybersand.sol-active-normal-live.evidence.v1',curation_source=identity['source'],
        runtime_build_source=identity['runtime_build_source'],curator_sha256=runtime.lfsha(Path(__file__)),input_sha256=inputs,files=files,
        raw_custody='Ignored raw receipts/logs/reports/dependency inventories/binaries retained locally; raw reports not substituted by compact views',
        original_SOL='NO-GO; no original SOL authority/composition or recurrence-clock admission'))
    print('Curated',len(files),'structured artifacts',sum(f.stat().st_size for f in output.iterdir()),'bytes')

if __name__=='__main__':main()
