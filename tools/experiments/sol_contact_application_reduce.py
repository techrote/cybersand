#!/usr/bin/env python3
"""Independent registered application, geometry and whole-window accounting."""
import argparse
from collections import Counter
import hashlib
from itertools import product
import json
import math
from pathlib import Path
import struct
import la_physical_reduce as geometry
import sol_active_normal_live_reduce as native
import sol_node_trace_audit as trace
import sol_node_trace_reduce as paths

ROOT=Path(__file__).resolve().parents[2]
REG='native/tests/fixtures/sol_contact_application_001.json'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode('utf-8'))
def digest(v):return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]
def cross32(a,b):return f32(f32(a[0]*b[1])-f32(a[1]*b[0]))
def ulp32(value):
    value=abs(f32(value));bits=struct.unpack('<I',struct.pack('<f',value))[0]
    return struct.unpack('<f',struct.pack('<I',bits+1))[0]-value
def effective(c):return c if f32(f32(c[0]*c[0])+f32(c[1]*c[1]))>1e-6 else [0.,0.]
def near(a,b,tol=1e-9):assert math.isfinite(a) and math.isfinite(b) and abs(a-b)<=tol,(a,b,tol)
def values(state):
    v=list(struct.unpack('<3d',bytes.fromhex(state['velocity_omega_f64le'])))
    assert all(math.isfinite(x) for x in v) and state['mass']>0 and state['inertia']>0
    ke=kinetic(v,state['mass'],state['inertia'])
    assert math.isclose(ke,state['kinetic'],rel_tol=1e-12,abs_tol=1e-9)
    return v
def kinetic(v,m,i):return .5*m*(v[0]*v[0]+v[1]*v[1])+.5*i*v[2]*v[2]
def payload(meta):
    result=geometry.tuples(paths.payload_path(meta['path']))
    assert result['sha256']==meta['sha256'] and result['bytes']==meta['bytes']
    return result
def summary(values):return dict(count=len(values),mean=math.fsum(values)/len(values),maximum=max(values),integral=math.fsum(values)/60.)

def application_record(row,action,sampled,live,after,final,variant):
    assert variant in ['baseline','retain-linear-001'] and action['age']==0
    assert sampled['pose_f64le']==live['pose_f64le'] and sampled['velocity_omega_f64le']==live['velocity_omega_f64le'],'Fresh synchronous core scope violated'
    assert sampled['center_of_mass_local']==live['center_of_mass_local']
    c=effective(row['correction']);assert action['correction']==c
    assert action['impulse']==row['impulse'],'Native wrench changed'
    # Equal fresh sampled/live transforms and fixed local COM imply their
    # identical float32 world COM cancels before the existing correction shift.
    torque=row['torque']+cross32([-c[0],-c[1]],row['impulse'])
    near(action['torque'],torque)
    assert ('linear_clip_policy' in action)==(variant=='retain-linear-001')
    if variant!='baseline':assert action['linear_clip_policy']==variant
    v=values(live);a=values(after);z=values(final);m=live['mass'];inertia=live['inertia']
    baseline=[0. if x*y<0 else x for x,y in zip(v[:2],c)]+[v[2]]
    applied=baseline if variant=='baseline' else v.copy()
    predicted=[applied[0]+action['impulse'][0]/m,applied[1]+action['impulse'][1]/m,applied[2]+action['torque']/inertia]
    error=max(math.hypot(predicted[0]-a[0],predicted[1]-a[1]),abs(predicted[2]-a[2]));assert error<=1e-5
    pose=list(struct.unpack('<6d',bytes.fromhex(live['pose_f64le'])));new=list(struct.unpack('<6d',bytes.fromhex(after['pose_f64le'])))
    expected_position=[f32(pose[4]+c[0]),f32(pose[5]+c[1])]
    position_error=max(abs(new[4+k]-expected_position[k]) for k in [0,1])
    # Rapier transform roundtrips normalize float32 rotation/COM. This bound
    # checks representation, not geometric clearance or behavior tolerance.
    assert max(abs(x-y) for x,y in zip(new[:4],pose[:4]))<=4*ulp32(1.)
    assert position_error<=4*max(ulp32(x) for x in pose[4:]+expected_position+[1.]),'Position correction changed'
    before_ke=kinetic(v,m,inertia);clip_ke=kinetic(applied,m,inertia);predicted_ke=kinetic(predicted,m,inertia);after_ke=kinetic(a,m,inertia)
    return dict(readback_error=error,position_representation_error=position_error,clip_impulse=[m*(applied[k]-v[k]) for k in [0,1]],clip_work=clip_ke-before_ke,
        counterfactual_baseline_clip_work=kinetic(baseline,m,inertia)-before_ke,wrench_work=predicted_ke-clip_ke,
        rounding_residual=after_ke-predicted_ke,response_work=after_ke-before_ke,rapier_work=kinetic(z,m,inertia)-after_ke,
        correction_potential=after['potential']-live['potential'],kinetic=kinetic(z,m,inertia),speed=math.hypot(*z[:2]),abs_omega=abs(z[2]),
        x_after_application=new[4],y_after_application=new[5],correction=c,impulse=action['impulse'],torque=action['torque'])

def hard_witnesses(observation,rectangles):
    assert not observation.get('outside');ox,oy=observation['origin'];width,height=observation['size'];cells=[]
    for material,count in observation['material_runs']:cells.extend([material]*count)
    assert len(cells)==width*height
    xx,xy,yx,yy,tx,ty=observation['pose'];count=0;maximum=0.;first=None
    for slot,rect in enumerate(rectangles):
        cx,cy=rect['center'];w,h=rect['size'];points=[(cx-w/2,cy-h/2),(cx+w/2,cy-h/2),(cx+w/2,cy+h/2),(cx-w/2,cy+h/2)]
        poly=[(tx+xx*x+yx*y,ty+xy*x+yy*y) for x,y in points]
        for y in range(max(oy,math.floor(min(p[1] for p in poly))),min(oy+height,math.ceil(max(p[1] for p in poly)))):
            for x in range(max(ox,math.floor(min(p[0] for p in poly))),min(ox+width,math.ceil(max(p[0] for p in poly)))):
                material=cells[(y-oy)*width+x-ox]
                if material in (0,2,14):continue
                area=geometry.overlap(poly,x,y)
                if area>1e-9:
                    count+=1;maximum=max(maximum,area)
                    if first is None:first=dict(proxy=slot,x=x,y=y,material=material,area=area)
    return dict(count=count,maximum_intersection_area=maximum,first=first)

def windows(records,states):
    result=[]
    for low,high in [[0,119],[120,239],[240,359],[0,179],[0,359]]:
        selected=records[low:high+1];poses=[struct.unpack('<6d',bytes.fromhex(s['pose_f64le'])) for s in states[low:high+1]]
        angles=[math.atan2(p[1],p[0]) for p in poses]
        result.append(dict(window=[low,high],motion={key:summary([r[key] for r in selected]) for key in ['kinetic','speed','abs_omega']},
            sand_area=summary([r['sand_area'] for r in selected]),sand_depth=summary([r['sand_depth'] for r in selected]),
            final_sand_area=selected[-1]['sand_area'],final_sand_depth=selected[-1]['sand_depth'],
            span_x=max(p[4] for p in poses)-min(p[4] for p in poses),span_y=max(p[5] for p in poses)-min(p[5] for p in poses),
            wrapped_angle_span=max(angles)-min(angles),terminal_speed=selected[-1]['speed']))
    return result

def audit_report(data,coordinate,registration):
    assert data['registration']=='SOL-CONTACT-APPLICATION-001-AUTHORED' and data['native_mode']==data['arm']=='LA-SELECTIVE'
    case=coordinate['case'];policy=coordinate['normal_policy'];variant=coordinate['application'];workers=coordinate['workers']
    assert data['case']['id']==case and data['requested_workers']==workers and data['repeat']==0 and not data['failures']
    assert [s['step'] for s in data['steps']]==list(range(360))
    initial=payload(data['initial_payload']);final=payload(data['final_payload'])
    assert initial['sha256']==registration['common_inputs']['initial_payloads'][case]
    assert initial['tuple_multiset']==final['tuple_multiset'],'Closed tuple multiset changed'
    initial_geometry=[geometry.geometry(g,a['geometry']) for g,a in zip(data['initial_geometry'],data['authored'])]
    assert all(not g['outside'] and g['area_by_material'].get(2,0)<=1e-6 and g['maximum_convex_proxy_depth'].get(2,0)<=2e-5 for g in initial_geometry)
    assert all(hard_witnesses(g,a['geometry'])['count']==0 for g,a in zip(data['initial_geometry'],data['authored']))
    owners={b['id']:b for b in data['initial_sample']['bodies']};n=len(owners);assert n==(3 if case.startswith('shared-') else 1)
    assert set(owners)==set(range(1,n+1));by_owner={k:[] for k in owners};states={k:[] for k in owners};traces=0
    native_rows=native.scalar_audit({'steps':[dict(step=s['step'],response=s['native_response']) for s in data['steps']]},policy)
    for step in data['steps']:
        number=step['step'];packet=step['native_response'];applied=step['application']
        assert packet['valid'] and packet['response']=='LA-SELECTIVE' and packet['session']==data['initial_sample']['session'] and packet['epoch']==data['initial_sample']['epoch'] and packet['sample_tick']==number
        assert packet['native_workers_configured']==packet['native_workers_constructed']==workers
        assert applied['accepted'] and not applied['refusal'] and applied['snapshot']==number+1 and applied['application_variant']==variant
        rows={v['id']:v for v in packet['rows']};actions={v['id']:v for v in applied['bodies']}
        assert len(rows)==len(packet['rows'])==n and len(actions)==len(applied['bodies'])==n and set(rows)==set(actions)==set(owners)
        assert all(len(step[k])==n for k in ['sampled','live_before_application','after_application','after_step','geometry','external'])
        enabled=coordinate['host']=='windows' and workers==1 and case.startswith('shared-')
        assert packet['solver_trace_mode']==('batch64-001' if enabled else 'off')
        for identity,owner in owners.items():
            row=rows[identity];action=actions[identity];slot=identity-1
            assert row['instance_id']==action['instance_id']==owner['instance_id'] and row['generation']==owner['generation'] and row['sample']==action['sample']
            assert row['budget']==owner['budget'] and row['proxy_count']==owner['count'] and 'refusal' not in action
            assert ('solver_trace' in row)==enabled
            if enabled:assert trace.audit(row['solver_trace'],row)['full_closure'];traces+=1
            rec=application_record(row,action,step['sampled'][slot],step['live_before_application'][slot],step['after_application'][slot],step['after_step'][slot],variant)
            observed=step['geometry'][slot];shape=data['authored'][slot]['geometry'];g=geometry.geometry(observed,shape);assert not g['outside']
            hard=hard_witnesses(observed,shape)
            initial_ke=kinetic(values(step['before'][slot]),step['before'][slot]['mass'],step['before'][slot]['inertia'])
            sample_ke=kinetic(values(step['sampled'][slot]),step['sampled'][slot]['mass'],step['sampled'][slot]['inertia'])
            live_ke=kinetic(values(step['live_before_application'][slot]),step['live_before_application'][slot]['mass'],step['live_before_application'][slot]['inertia'])
            explicit=step['external'][slot]['impulse_work']
            rec.update(step=number,body=identity,sand_area=g['area_by_material'].get(2,0.),sand_depth=g['maximum_convex_proxy_depth'].get(2,0.),hard=hard,
                explicit_work=explicit,preapplication_work=live_ke-sample_ke,pre_native_work=sample_ke-initial_ke,controller_or_other_work=sample_ke-initial_ke-explicit)
            near(rec['kinetic']-initial_ke,rec['pre_native_work']+rec['preapplication_work']+rec['response_work']+rec['rapier_work'])
            by_owner[identity].append(rec);states[identity].append(step['after_step'][slot])
    summary_rows=[]
    for identity,records in by_owner.items():
        win=windows(records,states[identity]);tail=next(w for w in win if w['window']==[240,359])
        static=tail['span_x']<=.5 and tail['span_y']<=.5 and tail['wrapped_angle_span']<=.05 and tail['terminal_speed']<=.5
        summary_rows.append(dict(body=identity,windows=win,static_screen=static,hard_witnesses=sum(r['hard']['count'] for r in records),
            first_hard=next((dict(step=r['step'],**r['hard']['first']) for r in records if r['hard']['first']),None),
            maximum_hard_intersection=max(r['hard']['maximum_intersection_area'] for r in records),
            work={k:math.fsum(r[k] for r in records) for k in ['clip_work','wrench_work','rounding_residual','response_work','rapier_work','correction_potential','explicit_work','pre_native_work','preapplication_work','controller_or_other_work']},
            maximum_readback_error=max(r['readback_error'] for r in records),maximum_position_representation_error=max(r['position_representation_error'] for r in records),maximum_positive_response_work=max(0.,max(r['response_work'] for r in records))))
    return dict(owners=summary_rows,initial_payload_sha256=initial['sha256'],final_payload_sha256=final['sha256'],tuple_multiset_conserved=True,
        body_applications=360*n,complete_traces=traces,arrival_count=sum(r['arrival_count'] for r in native_rows),arrival_missing=sum(r['arrival_missing'] for r in native_rows),arrival_misaligned=sum(r['arrival_misaligned'] for r in native_rows),
        actual_worker_ticks=dict(Counter(s['statistics']['values']['worker_threads_observed'] for s in data['steps'])),
        getter_mean_us=math.fsum(s['native_response']['getter_us'] for s in data['steps'])/360.,getter_max_us=max(s['native_response']['getter_us'] for s in data['steps']),
        simulation_mean_us=math.fsum(s['simulation_us'] for s in data['steps'])/360.,prefix_export_us=data.get('prefix_export_us'),
        arrival_storage_bytes_peak=max(s['native_response']['arrival_storage_bytes'] for s in data['steps'])),by_owner

def clean_record(value):
    if isinstance(value,dict):return {k:clean_record(v) for k,v in value.items() if k not in ['getter_us','center_of_mass_local','linear_clip_policy']}
    if isinstance(value,list):return [clean_record(v) for v in value]
    return value

def physical_step_equal(a,b):
    for field in ['before','sampled','live_before_application','after_application','after_step','external','controllers','geometry']:
        assert clean_record(a[field])==clean_record(b[field]),(a['step'],field)
    assert clean_record(a['native_response'])==clean_record(b['native_response']),(a['step'],'native_response')

def prefix_compare(data,old):
    assert data['initial_payload']['sha256']==old['initial_payload']['sha256']
    assert data['prefix_payload']['sha256']==old['final_payload']['sha256'],'Full180prefix CYPS mismatch'
    assert {k:v for k,v in data['case'].items() if k not in ['id','prefix_case']}=={k:v for k,v in old['case'].items() if k!='id'}
    for a,b in zip(data['steps'][:180],old['steps']):physical_step_equal(a,b)
    return dict(status='PASS',steps=180,prefix_sha256=data['prefix_payload']['sha256'])

def before_intervention(base,candidate,records):
    first=next((s['step'] for s in base['steps'] if any(records[i][s['step']]['clip_impulse']!=[0,0] for i in records)),360)
    for a,b in zip(base['steps'][:first],candidate['steps'][:first]):physical_step_equal(a,b)
    return dict(status='PASS',first_effective_clip_step=None if first==360 else first,matched_prior_steps=first)

def compare_gate(summaries):
    failures=[];improvements=[]
    def compare(a,b,metadata):
        if a>b:failures.append(dict(metadata,candidate=a,reference=b))
    def geo(a,b,metadata):
        for metric in ['sand_area','sand_depth']:
            for quantity in ['maximum','integral']:compare(a[metric][quantity],b[metric][quantity],dict(metadata,gate=metric+'_'+quantity))
        for metric in ['final_sand_area','final_sand_depth']:compare(a[metric],b[metric],dict(metadata,gate=metric))
    for host,worker in product(['windows','linux'],[1,4]):
        for case in ['barrel-rest','barrel-constrained-valid']:
            a=summaries[(host,worker,case,'active-retain')]['owners'][0];b=summaries[(host,worker,case,'active-baseline')]['owners'][0];meta=dict(host=host,workers=worker,case=case)
            if not a['static_screen']:failures.append(dict(meta,gate='static_screen'))
            geo(a['windows'][-1],b['windows'][-1],meta)
            for key in ['hard_witnesses','maximum_hard_intersection']:compare(a[key],b[key],dict(meta,gate=key))
        case='shared-granular-bodies-extended360';candidate=summaries[(host,worker,case,'active-retain')]['owners'];improved=False
        for reference in ['original-baseline','active-baseline']:
            baseline=summaries[(host,worker,case,reference)]['owners']
            for a,b in zip(candidate,baseline):
                assert a['body']==b['body'];meta=dict(host=host,workers=worker,case=case,body=a['body'],reference_arm=reference)
                for aw,bw in zip(a['windows'],b['windows']):
                    for metric in ['kinetic','speed','abs_omega']:
                        for quantity in ['mean','maximum']:compare(aw['motion'][metric][quantity],bw['motion'][metric][quantity],dict(meta,window=aw['window'],gate=metric+'_'+quantity))
                    geo(aw,bw,dict(meta,window=aw['window']))
                if reference=='active-baseline' and a['windows'][-1]['motion']['kinetic']['mean']<b['windows'][-1]['motion']['kinetic']['mean']-1e-9:improved=True
                for key in ['hard_witnesses','maximum_hard_intersection']:compare(a[key],b[key],dict(meta,gate=key))
        improvements.append(dict(host=host,workers=worker,strict_fullwindow_mean_KE_improvement_against_active=improved))
        if not improved:failures.append(dict(host=host,workers=worker,case=case,gate='strict_fullwindow_mean_KE_improvement'))
    return dict(status='PASS' if not failures else 'NO-GO',stage_b='ADMITTED' if not failures else 'NOT_ADMITTED_BY_REGISTERED_GATE',failures=failures,strict_improvement=improvements)

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    folder=args.directory.resolve();output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=paths.source_head();receipt_path=folder/'receipt.json';receipt=read(receipt_path);registration=read(ROOT/REG)
    assert receipt['post_source_equality'] and receipt['registration']==registration and receipt['matrix']['suite']=='core'
    assert receipt['matrix']['platforms']=='windows,linux' and receipt['matrix']['workers']=='1,4' and receipt['matrix']['repeats']==1 and not receipt['matrix']['cases'] and not receipt['matrix']['arms']
    coords=[dict(host=h,workers=w,case=c,**a) for h,w,c,a in product(['windows','linux'],[1,4],registration['stage_a']['cases'],registration['arms'])]
    for c in coords:c['tag']=c['case']+'-'+c['id']+'-w'+str(c['workers'])+'-r0'
    for h,state in receipt['hosts'].items():
        assert Counter(c['name'] for c in state['commands'] if 'reports' in c)==Counter(c['tag'] for c in coords if c['host']==h)
        assert state['post_inventory']['unexpected_changes']==[]
    entries=[];data_index={};summary_index={};record_index={};groups={}
    manifest=dict(evaluator='SOL-CONTACT-APPLICATION-001-INDEPENDENT',analysis_source=head,execution_source=receipt['identity']['source'],input_receipt_sha256=sha(receipt_path),registration_sha256=sha(ROOT/REG),status='IN_PROGRESS',results=entries,
        failed_commands=[dict(host=h,name=c['name'],exit=c['exit']) for h,s in receipt['hosts'].items() for c in s['commands'] if not c['clean']],
        scope='Complete copied observations; candidate gate separate; original SOL authority and full grain/body conservation unavailable')
    write(output/'manifest.json',manifest)
    for coordinate in coords:
        entry=dict(coordinate=coordinate,status='UNAVAILABLE');entries.append(entry)
        try:
            commands=[c for c in receipt['hosts'][coordinate['host']]['commands'] if c['name']==coordinate['tag']];assert len(commands)==1
            command=commands[0];assert command['clean'] and command['report_audit']=='PASS' and len(command['reports'])==1
            item=command['reports'][0];path=ROOT/item['path'].replace('\\','/');assert sha(path)==item['sha256'];data=read(path)
            assert data['source']==receipt['identity']['source']
            result,records=audit_report(data,coordinate,registration)
            result.update(raw_path=item['path'],raw_sha256=item['sha256'],raw_bytes=path.stat().st_size,process_seconds=command['seconds'])
            signature=digest(dict(initial=data['initial_payload']['sha256'],sample=data['initial_sample'],geometry=data['initial_geometry'],authored=data['authored'],case=data['case']))
            key=(coordinate['host'],coordinate['workers'],coordinate['case'],coordinate['id']);data_index[key]=data;summary_index[key]=result;record_index[key]=records
            groups.setdefault(key[:3],[]).append(signature)
            if coordinate['case'].startswith('shared-'):
                prefix=payload(data['prefix_payload']);assert prefix['tick']==prefix['completed_tick']==180 and prefix['tuple_multiset']==payload(data['initial_payload'])['tuple_multiset']
            write(output/(coordinate['host']+'-'+coordinate['tag']+'.json'),dict(coordinate=coordinate,summary=result,records=records))
            entry.update(status='PASS',summary=result);print(coordinate['host'],coordinate['tag'],'PASS',flush=True)
        except Exception as error:entry.update(status='FAIL',error=type(error).__name__+': '+str(error));print(coordinate['tag'],entry['error'],flush=True)
        write(output/'manifest.json',manifest)
    matched=[dict(group=list(k),arms=len(v),matched=len(v)==4 and len(set(v))==1) for k,v in groups.items()];manifest['matched_initial_groups']=matched
    prefixes=[];interventions=[];old_manifest=read(ROOT/'docs/audits/sol-node-trace-20261105/comparison.json')
    for host,worker,policy in product(['windows','linux'],[1,4],['original','active-normal-001']):
        arm='original' if policy=='original' else 'active';case='shared-granular-bodies-extended360';key=(host,worker,case,arm+'-baseline')
        try:
            old_entry=next(e for e in old_manifest['results'] if e['coordinate']['host']==host and e['coordinate']['workers']==worker and e['coordinate']['normal_policy']==policy and e['coordinate']['trace_mode']==('batch64-001' if host=='windows' and worker==1 else 'off'))
            path=ROOT/old_entry['summary']['raw_path'].replace('\\','/');assert sha(path)==old_entry['summary']['raw_sha256']
            prefixes.append(dict(host=host,workers=worker,normal_policy=policy,**prefix_compare(data_index[key],read(path))))
        except Exception as error:prefixes.append(dict(host=host,workers=worker,normal_policy=policy,status='FAIL',error=type(error).__name__+': '+str(error)))
        for case in registration['stage_a']['cases']:
            key=(host,worker,case,arm+'-baseline');candidate=(host,worker,case,arm+'-retain')
            try:interventions.append(dict(host=host,workers=worker,case=case,normal_policy=policy,**before_intervention(data_index[key],data_index[candidate],record_index[key])))
            except Exception as error:interventions.append(dict(host=host,workers=worker,case=case,normal_policy=policy,status='FAIL',error=type(error).__name__+': '+str(error)))
    complete=len(entries)==48 and all(e['status']=='PASS' for e in entries) and len(matched)==12 and all(g['matched'] for g in matched) and all(v['status']=='PASS' for v in prefixes+interventions) and not manifest['failed_commands']
    manifest.update(status='COMPLETE' if complete else 'INCOMPLETE_OR_FAILED',prefix_comparisons=prefixes,before_intervention=interventions,
        body_applications=sum(e.get('summary',{}).get('body_applications',0) for e in entries),complete_traces=sum(e.get('summary',{}).get('complete_traces',0) for e in entries))
    manifest['candidate_gate']=compare_gate(summary_index) if complete else dict(status='UNAVAILABLE',stage_b='NOT_ADMITTED_BY_REGISTERED_GATE')
    assert head==paths.source_head();write(output/'manifest.json',manifest)
    print('ACCOUNTING',manifest['status'],'CANDIDATE',manifest['candidate_gate']['status'],flush=True)
    return int(not complete)

if __name__=='__main__':raise SystemExit(main())
