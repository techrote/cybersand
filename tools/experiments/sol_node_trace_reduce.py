#!/usr/bin/env python3
"""Full registered trace coverage, physical parity and arithmetic accounting."""
import argparse
from collections import Counter
import hashlib
from itertools import product
import json
from pathlib import Path
import struct
import la_physical_reduce as physical
import sol_active_normal_live_authored_reduce as application
import sol_active_normal_live_reduce as scalar
import sol_node_trace_audit as trace
import la_selective_experiment as p

ROOT=Path(__file__).resolve().parents[2]
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
def write(path,value):path.write_bytes((json.dumps(value,indent=2)+'\n').encode('utf-8'))
def stats(values):
    ordered=sorted(values)
    return dict(count=len(values),mean=sum(values)/len(values),maximum=max(values),p50=ordered[(len(values)-1)//2],p95=ordered[int((len(values)-1)*.95)])

TRACE_KEYS={'solver_trace','solver_trace_mode','solver_trace_locked','solver_trace_storage_bytes','getter_us'}
def physical_packet(value):
    if isinstance(value,dict):return {k:physical_packet(v) for k,v in value.items() if k not in TRACE_KEYS}
    if isinstance(value,list):return [physical_packet(v) for v in value]
    return value

def pristine(data):
    return dict(payload=data['initial_payload']['sha256'],geometry=data['initial_geometry'],sample=data['initial_sample'],authored=data['authored'],case=data['case'])

def parity(off,on):
    assert pristine(off)==pristine(on),'Mismatched initial authoritative inputs'
    assert off['final_payload']['sha256']==on['final_payload']['sha256'],'Final CYPS mismatch'
    assert len(off['steps'])==len(on['steps'])==180
    fields=['before','sampled','live_before_application','after_application','after_step','external','controllers','geometry','application','emission_requests','inserted_materials']
    for first,second in zip(off['steps'],on['steps']):
        assert first['step']==second['step']
        for field in fields:assert first[field]==second[field],(first['step'],field)
        assert physical_packet(first['native_response'])==physical_packet(second['native_response']),(first['step'],'native_response')
    return dict(status='PASS',steps=180,owners=3,initial_sha256=off['initial_payload']['sha256'],final_sha256=off['final_payload']['sha256'],
        excluded='Getter timing and four explicit trace diagnostic keys only; stage timing/statistics are separately reported, not compared as deterministic physical state')

def first_differences(original,active):
    output=[]
    for owner in [1,2,3]:
        found={}
        for first,second in zip(original['steps'],active['steps']):
            ca=next(r['solver_trace'] for r in first['native_response']['rows'] if r['id']==owner)
            cb=next(r['solver_trace'] for r in second['native_response']['rows'] if r['id']==owner)
            for kind,keys in [('node_input',['body_f64le','solve_f64le','nodes_f64le','node_meta_f64']),('batch_arithmetic',['batches_f64le','steps_f64le']),('result',['result_f64le'])]:
                if kind not in found and any(ca[k]!=cb[k] for k in keys):
                    found[kind]=dict(step=first['step'],different_fields=[k for k in keys if ca[k]!=cb[k]],
                        exact_body_equal=ca['body_f64le']==cb['body_f64le'],exact_nodes_equal=ca['nodes_f64le']==cb['nodes_f64le'],original=ca,active=cb)
            ra=struct.unpack('<19d',bytes.fromhex(ca['result_f64le']));rb=struct.unpack('<19d',bytes.fromhex(cb['result_f64le']))
            if 'wrench' not in found and any(ra[k]!=rb[k] for k in [0,1,6,7,8,9]):
                found['wrench']=dict(step=first['step'],exact_body_equal=ca['body_f64le']==cb['body_f64le'],exact_nodes_equal=ca['nodes_f64le']==cb['nodes_f64le'],
                    original_wrench=[ra[k] for k in [0,1,8]],active_wrench=[rb[k] for k in [0,1,8]],original=ca,active=cb)
        output.append(dict(body=owner,differences=found))
    return output

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument('directory',type=Path);parser.add_argument('--output',required=True,type=Path);args=parser.parse_args()
    folder=args.directory.resolve();output=args.output.resolve();assert not output.exists();output.mkdir(parents=True)
    head=p.git('rev-parse','HEAD').decode().strip();receipt_path=folder/'receipt.json';receipt=read(receipt_path)
    assert receipt['post_source_equality'] and receipt['matrix']['suite']=='qualification'
    registration=receipt['registration']['live_campaign']
    assert registration['episodes']==16 and registration['repeats']==1
    coordinates=[]
    for host,worker,policy,mode in product(['windows','linux'],[1,4],['original','active-normal-001'],['off','batch64-001']):
        label='selective-original' if policy=='original' else 'selective-active'
        tag='shared-granular-bodies-'+label+'-'+mode+'-w'+str(worker)+'-r0'
        coordinates.append(dict(host=host,workers=worker,normal_policy=policy,trace_mode=mode,tag=tag))
    params=receipt['matrix']
    assert params['platforms']=='windows,linux' and params['workers']=='1,4' and params['repeats']==1 and not params['cases'] and not params['arms']
    assert set(receipt['hosts'])=={'windows','linux'}
    for host,state in receipt['hosts'].items():
        expected={c['tag'] for c in coordinates if c['host']==host}
        attempts=[c['name'] for c in state['commands'] if 'reports' in c]
        assert len(attempts)==8 and set(attempts)==expected,'Missing, duplicate or unexpected episode'
    entries=[];data_index={};trace_rows=[]
    manifest=dict(evaluator='SOL-NODE-TRACE-001-INDEPENDENT',status='IN_PROGRESS',analysis_source=head,execution_source=receipt['identity']['source'],
        runtime_build_source=receipt['identity']['runtime_build_source'],input_receipt_sha256=sha(receipt_path),results=entries,
        qualification='Arithmetic/observation parity only; no original SOL authority, clearance, full conservation or clean causal timing claim')
    manifest['failed_commands']=[dict(host=h,name=c['name'],exit=c['exit']) for h,s in receipt['hosts'].items() for c in s['commands'] if not c['clean']]
    manifest['post_projects']=all(s['post_inventory']['unexpected_changes']==[] for s in receipt['hosts'].values())
    write(output/'manifest.json',manifest)
    for coordinate in coordinates:
        host=coordinate['host'];tag=coordinate['tag'];entry=dict(coordinate=coordinate,status='UNAVAILABLE');entries.append(entry)
        try:
            commands=[c for c in receipt['hosts'][host]['commands'] if c['name']==tag];assert len(commands)==1
            command=commands[0];assert command['clean'] and command['report_audit']=='PASS' and len(command['reports'])==1
            item=command['reports'][0];path=ROOT/item['path'].replace('\\','/');assert sha(path)==item['sha256'];data=read(path)
            assert data['source']==receipt['identity']['source'] and data['registration']=='SOL-NODE-TRACE-001-AUTHORED'
            assert data['requested_workers']==coordinate['workers'] and not data['failures']
            assert data['case']['id']=='shared-granular-bodies' and data['repeat']==0 and data['arm']==data['native_mode']=='LA-SELECTIVE'
            assert [s['step'] for s in data['steps']]==list(range(180))
            checked=physical.report(path);assert checked['final'] and checked['material_source_ledger_closes'] and checked['closed_tuple_multiset_equal']
            actions=application.application_audit(data,dict(normal_policy=coordinate['normal_policy'],workers=coordinate['workers']))
            scalars=scalar.scalar_audit({'steps':[dict(step=s['step'],response=s['native_response']) for s in data['steps']]},coordinate['normal_policy'])
            enabled=coordinate['trace_mode']=='batch64-001';captures=[];payload_bytes=0
            for step in data['steps']:
                packet=step['native_response'];assert packet['solver_trace_mode']==coordinate['trace_mode'] and packet['solver_trace_locked']
                assert packet['solver_trace_storage_bytes']==(55872 if enabled else 0)
                for row in packet['rows']:
                    assert ('solver_trace' in row)==enabled
                    if enabled:
                        capture=row['solver_trace'];result=trace.audit(capture,row);assert result['full_closure'],'Incomplete capture cannot close registered causal comparison'
                        payload_bytes+=len(json.dumps(capture,separators=(',',':')).encode())
                        captures.append(result)
                        trace_rows.append(dict(host=host,workers=coordinate['workers'],normal_policy=coordinate['normal_policy'],step=step['step'],body=row['id'],
                            instance_id=row['instance_id'],generation=row['generation'],sample=row['sample'],capture_sha256=digest(capture),
                            **{k:v for k,v in result.items() if k not in ['node_input_bits','result_bits']}))
            assert len(captures)==(540 if enabled else 0)
            summary=dict(status='PASS',raw_path=item['path'],raw_sha256=item['sha256'],raw_bytes=path.stat().st_size,process_seconds=command['seconds'],
                complete_captures=len(captures),maximum_nodes=max((c['nodes'] for c in captures),default=0),trace_payload_json_bytes=payload_bytes,
                actual_worker_tick_distribution=dict(Counter(s['statistics']['values']['worker_threads_observed'] for s in data['steps'])),
                tuple_multiset_conserved=True,initial_payload_sha256=data['initial_payload']['sha256'],final_payload_sha256=data['final_payload']['sha256'],
                maximum_RID_error=actions['maximum_RID_error'],selected_arrivals=sum(s['arrival_count'] for s in scalars),arrival_missing=sum(s['arrival_missing'] for s in scalars),arrival_misaligned=sum(s['arrival_misaligned'] for s in scalars),
                passive_rejections=sum(s['passive_rejected'] for s in scalars),actual_response_work=sum(s['actual_response_work'] for s in actions['records']),rapier_step_work=sum(s['rapier_step_work'] for s in actions['records']),
                explicit_api_work=sum(s['explicit_api_work'] for s in actions['records']),correction_potential_change=sum(s['correction_potential_change'] for s in actions['records']),
                getter_us=stats([s['native_response']['getter_us'] for s in data['steps']]),simulation_us=stats([s['simulation_us'] for s in data['steps']]),observation_us=stats([s['observation_us'] for s in data['steps']]),
                terminal_stability=checked['stability'],initial_geometry=checked['initial_geometry'],
                maximum_sand_area=max(g['area_by_material'].get(2,0.) for s in checked['geometry_observations'] for g in s['bodies']),
                maximum_sand_proxy_depth=max(g['maximum_convex_proxy_depth'].get(2,0.) for s in checked['geometry_observations'] for g in s['bodies']))
            data_index[(host,coordinate['workers'],coordinate['normal_policy'],coordinate['trace_mode'])]=data
            entry.update(status='PASS',summary=summary)
            print(host,tag,'PASS',len(captures),flush=True)
        except Exception as error:
            entry.update(status='FAIL',error=type(error).__name__+': '+str(error));print(host,tag,entry['error'],flush=True)
        write(output/'manifest.json',manifest)
    pairs=[];divergences=[];retained_pairs=[]
    for host,worker,policy in product(['windows','linux'],[1,4],['original','active-normal-001']):
        entry=dict(host=host,workers=worker,normal_policy=policy,status='UNAVAILABLE');pairs.append(entry)
        try:entry.update(parity(data_index[(host,worker,policy,'off')],data_index[(host,worker,policy,'batch64-001')]))
        except Exception as error:entry.update(status='FAIL',error=type(error).__name__+': '+str(error))
    for host,worker in product(['windows','linux'],[1,4]):
        if all((host,worker,policy,'batch64-001') in data_index for policy in ['original','active-normal-001']):
            divergences.append(dict(host=host,workers=worker,owners=first_differences(data_index[(host,worker,'original','batch64-001')],data_index[(host,worker,'active-normal-001','batch64-001')])))
    retained_path=ROOT/'docs/audits/sol-active-normal-live-20261105/authored-full-reduction.json'
    retained=read(retained_path);assert retained['status']=='COMPLETE'
    for host,worker,policy in product(['windows','linux'],[1,4],['original','active-normal-001']):
        label='selective-original' if policy=='original' else 'selective-active'
        name=host+'-shared-granular-bodies-'+label+'-w'+str(worker)+'-r0'
        item=next(e for e in retained['results'] if e['name']==name)
        entry=dict(host=host,workers=worker,normal_policy=policy,status='UNAVAILABLE',retained_source=retained['execution_source'],
            retained_path=item['summary']['raw_path'],retained_sha256=item['summary']['raw_sha256']);retained_pairs.append(entry)
        try:
            path=ROOT/entry['retained_path'].replace('\\','/');assert sha(path)==entry['retained_sha256']
            entry.update(parity(read(path),data_index[(host,worker,policy,'off')]))
        except Exception as error:entry.update(status='FAIL',error=type(error).__name__+': '+str(error))
    write(output/'trace-accounting.json',trace_rows);write(output/'first-differences.json',divergences)
    manifest.update(traceoff_on_pairs=pairs,retained_trajectory_comparisons=retained_pairs,retained_manifest_sha256=sha(retained_path),trace_accounting_sha256=sha(output/'trace-accounting.json'),first_differences_sha256=sha(output/'first-differences.json'),
        episodes=len(entries),steps=sum(180 for e in entries if e['status']=='PASS'),body_applications=sum(540 for e in entries if e['status']=='PASS'),complete_captures=len(trace_rows))
    complete=not manifest['failed_commands'] and manifest['post_projects'] and all(e['status']=='PASS' for e in entries) and all(e['status']=='PASS' for e in pairs) and len(divergences)==4
    manifest['status']='COMPLETE' if complete else 'INCOMPLETE_OR_FAILED'
    assert head==p.git('rev-parse','HEAD').decode().strip();write(output/'manifest.json',manifest)
    return int(not complete)

if __name__=='__main__':raise SystemExit(main())
