#!/usr/bin/env python3
"""Independent read-only peer of source identity, RG8 crops and terminal owners."""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace-root',type=Path,default=Path('/workspace/scratch/0b2a9bdf7883'))
parser.add_argument('--output',type=Path)
args=parser.parse_args()
base=args.workspace_root
root=base/'cybersand-physics'
receipt=base/'evidence-b/presentation-endpoints/receipt.json'
raw=receipt.read_bytes()
sha=lambda value:hashlib.sha256(value).hexdigest()
assert sha(raw)=='5b9bc187653ff32c5f6053cb43be7b59e017e84da2f33dc479a1a5763f3a70bf'
data=json.loads(raw)
assert data['failures']==[] and data['schema']=='pubpres-endpoint-causal-diagnostic-v1'
application='498fa47da062db702a74665f177e06f454d956aa'
native_source='c2f8a73d34448bc1496ecd84bca02f0812c80d27'
identity=data['identity']
assert identity['source']==application and identity['display']=='headless'
checked_sources={}
for relative in ('scripts/main.gd','scripts/workbench_presentation_coherence.gd'):
    committed=subprocess.check_output(['git','-C',str(root),'show',application+':godot/'+relative])
    assert identity['res://'+relative]==sha(committed)
    checked_sources[relative]=sha(committed)
probe=root/'godot/tests/pubpres_endpoint_diagnostic.gd'
assert sha(probe.read_bytes())==identity['res://tests/pubpres_endpoint_diagnostic.gd']=='495a75aa49bc6470f3a9ff6c09d9417b9b0a062e880716855cc22073eadb698c'
assert not subprocess.check_output(['git','-C',str(root),'diff','--name-only',native_source,application,'--','native','godot/native_extension'])
runtime_files={
    'engine_sha256':base/'toolchain/godot47/Godot_v4.7-stable_linux.x86_64',
    'res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so':root/'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so',
    'res://addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so':root/'godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so',
}
for key,path in runtime_files.items():
    assert sha(path.read_bytes())==identity[key],key
labels=['paused_initial','ordinary_step_120','ordinary_step_240','ordinary_step_360','ordinary_step_480','ordinary_step_600','paused_camera_return']
assert [c['label'] for c in data['captures']]==labels
owners=None
plane_rows=[]
crop_bound_rounding_differences=[]
for index,capture in enumerate(data['captures']):
    expected_step=min(index*120,600)
    assert type(capture['step']) is int and capture['step']==expected_step==capture['actual_manual_steps']
    assert type(capture['actual_manual_steps']) is int
    assert [b['slot'] for b in capture['bodies']]==list(range(8))
    current_owners=[b['rid'] for b in capture['bodies']]
    assert len(set(current_owners))==8 and all(type(v) is str and int(v)>0 for v in current_owners)
    if owners is None:owners=current_owners
    assert current_owners==owners
    for body in capture['bodies']:
        assert body['live']==body['actual_rid_pose']
        angle=body['actual_rid_pose']['radians'];px,py=body['actual_rid_pose']['xy']
        assert all(math.isfinite(v) for v in (angle,px,py))
        cosine,sine=math.cos(angle),math.sin(angle)
        for history in ('current','previous'):
            record=body[history]
            if not record:continue
            occupied=[];cells=0;min_edge_distance=float('inf')
            assert len(record['crops'])==1
            for crop in record['crops']:
                payload=base64.b64decode(crop['bytes_base64'],validate=True)
                assert sha(payload)==crop['sha256'] and crop['format']==3
                x0,y0,width,height=crop['rect'];cx,cy=crop['local_center'];sx,sy=crop['size']
                assert [cx,cy]==[0.0,0.0] and [sx,sy]==([7.0,3.0] if body['slot']<7 else [8.0,14.0])
                assert all(type(v) is int for v in (x0,y0,width,height)) and width>0 and height>0
                assert 0<=x0<x0+width<=512 and 0<=y0<y0+height<=512
                assert len(payload)==width*height*2
                center=(px+cosine*cx-sine*cy,py+sine*cx+cosine*cy)
                extent=(abs(cosine)*sx/2+abs(sine)*sy/2,abs(sine)*sx/2+abs(cosine)*sy/2)
                expected_low=[max(0,math.floor(center[a]-extent[a])-1) for a in (0,1)]
                expected_high=[min(512,math.ceil(center[a]+extent[a])+1) for a in (0,1)]
                double_bounds=[*expected_low,expected_high[0]-expected_low[0],expected_high[1]-expected_low[1]]
                if crop['rect']!=double_bounds:
                    crop_bound_rounding_differences.append({'capture':capture['label'],'slot':body['slot'],'history':history,
                                                          'actual':crop['rect'],'double_precision_box':double_bounds})
                # The float32 Godot extent can round an almost-integral edge
                # differently from the independent double trig reconstruction.
                # Require complete body-cell coverage, not equality of unused
                # border pixels in these two conservative bounding rectangles.
                all_body_cells=set()
                for y in range(expected_low[1],expected_high[1]):
                    for x in range(expected_low[0],expected_high[0]):
                        dx=x+.5-px;dy=y+.5-py
                        lx=cosine*dx+sine*dy-cx;ly=-sine*dx+cosine*dy-cy
                        if abs(lx)<=sx/2+.0001 and abs(ly)<=sy/2+.0001:
                            assert x0<=x<x0+width and y0<=y<y0+height
                            all_body_cells.add((x,y))
                observed_body_cells=set()
                for iy in range(height):
                    for ix in range(width):
                        dx=x0+ix+0.5-px;dy=y0+iy+0.5-py
                        local=(cosine*dx+sine*dy-cx,-sine*dx+cosine*dy-cy)
                        min_edge_distance=min(min_edge_distance,abs(abs(local[0])-sx/2-.0001),abs(abs(local[1])-sy/2-.0001))
                        if abs(local[0])<=sx/2+.0001 and abs(local[1])<=sy/2+.0001:
                            observed_body_cells.add((x0+ix,y0+iy))
                            cells+=1;offset=2*(iy*width+ix)
                            if payload[offset]:occupied.append({'x':x0+ix,'y':y0+iy,'material':payload[offset],'state':payload[offset+1]})
                assert observed_body_cells==all_body_cells
            assert min_edge_distance>.00001
            assert cells==record['cells'] and occupied==record['occupied']
            plane_rows.append({'capture':capture['label'],'slot':body['slot'],'history':history,'cells':cells,
                               'occupied_cells':len(occupied),'materials':sorted(set(c['material'] for c in occupied)),
                               'minimum_cell_boundary_distance':min_edge_distance})
terminal=data['captures'][-1]
frame=terminal['latest']['native_frame'];gcr=terminal['gcr']
assert terminal['native_tick']==terminal['step']==terminal['actual_manual_steps']==frame['tick']==600
assert terminal['world_generation']==frame['world_generation']==3
assert gcr['valid'] is True and gcr['session']==frame['session']==1 and gcr['epoch']==frame['epoch']==1
assert gcr['sample_tick']==frame['sample_tick']==599
assert terminal['latest']['step']==600 and terminal['latest']['time_usec']<=terminal['time_usec']
assert terminal['latest']['guard']['budget_vetoes']==0 and terminal['unresolved']==63 and terminal['displaced']==0
assert sum(r['unresolved'] for r in gcr['rows'])==terminal['unresolved']
terminal_rows=[]
for slot in (4,5,6):
    body=terminal['bodies'][slot];instance=str(slot+1)
    observed=frame['instances'][instance]
    response=next(r for r in gcr['rows'] if r['id']==slot+1)
    assert response['instance_id']==body['state']['instance_id']==slot+1
    assert response['generation']==observed['generation']==body['state']['generation']==1
    assert response['sample']==observed['sample']==601
    assert response['unresolved']==21 and response['displaced']==0
    assert terminal['latest']['sources'][str(slot)]=='hidden'
    queries=[q for q in terminal['latest']['queries'] if q['slot']==slot]
    assert len(queries)==3 and [q['result']['reason'] for q in queries]==['bounded_pose_delta','material_in_swept_mask','material_in_swept_mask']
    assert queries[0]['endpoint_only'] is False
    for query in queries[1:]:
        assert query['endpoint_only'] is True and query['start']==query['target']==body['actual_rid_pose']
        assert query['result']['safe'] is False
    for history in ('current','previous'):
        assert len(body[history]['occupied'])==21 and all(c['material']==3 for c in body[history]['occupied'])
    terminal_rows.append({'slot':slot,'instance':slot+1,'actual_rid':body['rid'],'actual_pose':body['actual_rid_pose'],
                          'sample':response['sample'],'generation':response['generation'],'water_current':21,'water_previous':21,
                          'native_unresolved':21,'native_displaced':0,'endpoint_refusals':2,'initial_sweep_reason':'bounded_pose_delta'})
result={'schema':'pubpres-submerged-endpoint-independent-peer-v1','receipt_sha256':sha(raw),'reader_sha256':sha(Path(__file__).read_bytes()),
        'application_source':application,'native_build_source':native_source,'application_native_inputs_unchanged':True,
        'actual_runtime_hashes_verified':{k:identity[k] for k in runtime_files},'application_files_verified':checked_sources,
        'probe_sha256':sha(probe.read_bytes()),'planes_checked':len(plane_rows),'planes':plane_rows,
        'all_footprint_cell_centers_covered':True,'unused_crop_border_rounding_differences':crop_bound_rounding_differences,
        'actual_rids_unique_and_stable':True,'terminal_identity_joins':terminal_rows,'passed':True,
        'limits':['Separate headless neutral/no-paint causal stimulus, not historical-capture replay or gameplay timing.',
                  'Full parent image hashes are retained but full parent bytes were not exported; bounded crops are source-bound actual get_region observations, not a separate cryptographic proof of the whole parent image.',
                  'Active snapshots legitimately lag physical completion; the strict contemporaneous native/material/endpoint finding uses the settled paused terminal only.',
                  'Recorded native Transform2D strings are rounded; the two actual endpoint-query numeric poses, rather than parsed rounded strings, match direct RID poses.',
                  'No graphical pixel, GPU completion, submitted camera matrix, physical NVIDIA or production-acceptance claim.'],
        'validator_hardening_requested':['Explicit unique/stable RID and terminal World/session/epoch/sample/generation predicates in reusable endpoint reader.'],
        'physical_acceptance':'HOLD'}
output=args.output or base/'evidence-c/submerged-endpoint-independent-peer.json'
output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'output':str(output),'sha256':sha(output.read_bytes()),'planes':len(plane_rows),'passed':True}))
