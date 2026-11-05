#!/usr/bin/env python3
"""Independent registered-coordinate and pristine-input checks; no response decisions."""
from collections import Counter
from itertools import product
import hashlib
import json

def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()

def coordinates(receipt,full=False):
    profile=receipt['registration']['chamber'];params=receipt['matrix']
    platforms=profile['platforms'] if full else params['platforms'].split(',')
    workers=profile['workers'] if full else list(map(int,params['workers'].split(',')))
    repeats=profile['repeats'] if full else params['repeats']
    cases=profile['cases'];arms=profile['arms']
    if not full:
        if params['cases']:cases=[c for c in cases if c in params['cases'].split(',')]
        if params['arms']:arms=[a for a in arms if a['id'] in params['arms'].split(',')]
    return {tuple([host,case,arm['id'],arm['normal_policy'],worker,repeat]):
        dict(platform=host,case=case,arm_id=arm['id'],normal_policy=arm['normal_policy'],mode=arm['mode'],workers=worker,repeat=repeat)
        for host,case,arm,worker,repeat in product(platforms,cases,arms,workers,range(repeats))}

def tag(coordinate):
    return coordinate['case']+'-'+coordinate['arm_id']+'-w'+str(coordinate['workers'])+'-r'+str(coordinate['repeat'])

def coverage(receipt):
    expected=coordinates(receipt);full=coordinates(receipt,True)
    tags={(v['platform'],tag(v)):key for key,v in expected.items()}
    seen=Counter();unexpected=[];missing_reports=[];failed=[];commands=0
    for host,state in receipt['hosts'].items():
        for command in state['commands']:
            commands+=1;key=tags.get((host,command['name']))
            if not command['clean']:failed.append(dict(host=host,name=command['name'],exit=command['exit']))
            if key is None:
                if command.get('reports'):unexpected.append(dict(host=host,name=command['name']))
                continue
            seen[key]+=1
            if len(command.get('reports',[]))!=1 or command.get('report_audit')!='PASS':missing_reports.append(list(key))
    missing=[list(key) for key in expected if seen[key]==0]
    duplicates=[dict(coordinate=list(key),attempts=count) for key,count in seen.items() if count!=1]
    post=receipt.get('post_source_equality') is True and all(
        state.get('post_inventory',{}).get('unexpected_changes')==[] for state in receipt['hosts'].values())
    complete=not (missing or duplicates or unexpected or missing_reports or failed) and post
    return dict(expected_coordinates=len(expected),attempted_episodes=sum(seen.values()),unique_coordinates=len(seen),
        total_process_commands=commands,missing=missing,duplicates=duplicates,unexpected=unexpected,
        failed_commands=failed,missing_or_failed_report_audits=missing_reports,post_identity_and_inventory=post,
        complete_requested_execution=complete,requested_equals_full_registration=set(expected)==set(full),
        complete_registered_execution=complete and set(expected)==set(full))

def bind(data,coordinate,source):
    assert data['source']==source and data['live_registration']=='SOL-ACTIVE-NORMAL-LIVE-001'
    assert data['case']['id']==coordinate['case'] and data['mode']==coordinate['mode']
    assert data['normal_policy']==coordinate['normal_policy']
    assert data['requested_workers']==coordinate['workers'] and data['repeat']==coordinate['repeat']
    assert [s['step'] for s in data['steps']]==list(range(180))

def initial_signature(data,result):
    def state(value):return {k:v for k,v in value.items() if k!='rid'}
    initial=data['initial'];payload=result['initial_payload']
    # Uniform per-material tuples plus the complete material location map prove
    # tuple locations here. A mixed-state map would need a richer decoder.
    variants=Counter(row[0][0] for row in payload['tuple_multiset'])
    assert all(count==1 for count in variants.values()),'Initial tuple-location proof unavailable for mixed states'
    roi_counts={int(k):v for k,v in result['initial']['roi_counts'].items() if int(k)!=0}
    assert roi_counts==payload['material_counts'],'Initial material outside observed ROI'
    assert payload['tick']==payload['completed_tick']==0
    signature=dict(initial_payload_sha256=payload['sha256'],geometry_f64le=data['geometry_f64le'],actual_shapes=data['actual_shapes'],sample=data['initial_sample'],
        pristine=state(data['pristine']),initial_body_state=state(initial['state']),
        origin=initial['origin'],size=initial['size'],materials=initial['material_runs'],mask=initial['mask_runs'],
        tuples=payload['tuple_multiset'],water_quantity=payload['water_quantity'],cadence=data['fixed_delta'],
        physics_tick_rate=data['physics_tick_rate'],force=[s['force'] for s in data['steps']])
    return digest(signature)

def common_inputs(groups,expected):
    requested=Counter((v['platform'],v['case'],v['workers'],v['repeat']) for v in expected.values())
    result=[]
    for key,count in requested.items():
        entries=groups.get(key,[]);signatures={e['signature'] for e in entries}
        result.append(dict(group=list(key),expected_arms=count,observed_arms=len(entries),
            distinct_signatures=len(signatures),matched=len(entries)==count and len(signatures)==1,
            arms=[e['arm'] for e in entries],initial_payload_sha256=sorted({e['payload_sha256'] for e in entries})))
    return result
