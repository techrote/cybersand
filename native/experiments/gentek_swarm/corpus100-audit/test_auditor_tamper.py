#!/usr/bin/env python3
"""Corrupt copies only; retained native evidence is never modified."""
from pathlib import Path
import copy, hashlib, json
import audit_corpus100 as a

ROOT=Path('/workspace/scratch/3a7df071dddd/corpus100-qualified/native')
OUT=Path('/workspace/scratch/3a7df071dddd/review')
results=[]

def read(cid): return json.loads((ROOT/(cid+'.json')).read_text())
def bind_result(q,r):
    r['request_digest']=a.request_digest(q)
    r['material_digest']=a.material_digest(r)
    r['digest']=a.semantic_digest(r)
def bind_pair(p):
    for side in ('left','right'):bind_result(p[side+'_request'],p[side])
    ld,rd=int(p['left']['digest'],16),int(p['right']['digest'],16)
    rotate=((rd<<17)|(rd>>47))&a.MASK
    p['digest']=f"{a.mix(ld^rotate^int(p['fixture_digest'],16)^p['work']^p['bridges']^p['unresolved_seams']^a.mix(p['typed_contacts'])^a.mix(p['bridge_cells'])):016x}"
def test(label,d,fn):
    auditor=a.Audit();auditor.case='tamper:'+label
    try:fn(auditor,d)
    except AssertionError as err:
        results.append({'mutation':label,'detected':True,'reason':str(err)})
        print(label+' DETECTED '+str(err),flush=True)
    else:raise AssertionError('Mutation escaped auditor: '+label)
def single(auditor,d):auditor.result(d['request'],d['result'],'single')
def pair(auditor,d):auditor.pair(d)

d=read('C100-001');i=next(i for i,c in enumerate(d['result']['cells']) if c)
d['result']['cells'][i]=0
test('native_material_digest_corruption',d,single)

d=read('C100-001');i=next(i for i,c in enumerate(d['result']['cells']) if c)
d['result']['provenance'][i]=0;bind_result(d['request'],d['result'])
test('unowned_material_even_with_recomputed_digests',d,single)

d=read('C100-001');i=next(i for i,c in enumerate(d['result']['cells']) if c)
d['request']['protected'][i]=1;bind_result(d['request'],d['result'])
test('protected_material_even_with_recomputed_digests',d,single)

d=read('C100-100');assert d['result']['status']=='unsat' and d['result']['solver_work'] is None
d['result']['solver_work']=0
test('unavailable_solver_work_fabricated_as_zero',d,single)

required=None
for path in sorted(ROOT.glob('*.json')):
    p=json.loads(path.read_text())
    if p['type']!='pair':continue
    for s in p['seams']:
        if not s['joined']:continue
        for side,key in (('left','left_affordance'),('right','right_affordance')):
            offer=next(z for z in p[side]['boundary']['hard'] if z['id']==s[key])
            if offer['required']:
                matches=[z for z in p[side]['connectors'] if all(z[k]==offer[k] for k in ('instance','family','a','b','facing'))]
                assert len(matches)==1
                required=(p,side,offer,matches[0]);break
        if required:break
    if required:break
assert required
p,side,offer,connector=required
d=copy.deepcopy(p);r=d[side];r['connectors']=[c for c in r['connectors'] if c['id']!=connector['id']]
if connector['required']:
    r['metrics']['mandatory_connectors']-=1
    r['metrics']['fulfilled_mandatory_connectors']-=int(connector['fulfilled'])
    r['unresolved_joints']-=int(not connector['fulfilled'])
else:
    r['metrics']['optional_connectors']-=1
    r['metrics']['fulfilled_optional_connectors']-=int(connector['fulfilled'])
bind_pair(d)
test('missing_exact_required_receipt_with_recomputed_digests',d,pair)

d=copy.deepcopy(p);r=d[side];duplicate=copy.deepcopy(connector);duplicate['id']=1+max(c['id'] for c in r['connectors']);r['connectors'].append(duplicate)
if duplicate['required']:
    r['metrics']['mandatory_connectors']+=1
    r['metrics']['fulfilled_mandatory_connectors']+=int(duplicate['fulfilled'])
    r['unresolved_joints']+=int(not duplicate['fulfilled'])
else:
    r['metrics']['optional_connectors']+=1
    r['metrics']['fulfilled_optional_connectors']+=int(duplicate['fulfilled'])
bind_pair(d)
test('duplicate_required_receipt_with_recomputed_digests',d,pair)

d=read('C100-047');s=next(s for s in d['seams'] if s['joined'] and len(s['cells'])>3);s['cells'][1][0]+=3
test('claimed_join_path_gap',d,pair)

d=read('C100-047');s=next(s for s in d['seams'] if s['joined']);side='left'
offer=next(z for z in d[side]['boundary']['hard'] if z['id']==s['left_affordance'])
matches=[z for z in d[side]['connectors'] if all(z[k]==offer[k] for k in ('instance','family','a','b','facing'))]
new=[-x for x in offer['facing']];assert new!=[0,0]
offer['facing']=new
for c in matches:c['facing']=new
bind_pair(d)
test('wrong_socket_facing_with_recomputed_digests',d,pair)

d=read('C100-047');inst=next(z for side in ('left','right') for z in d[side]['instances'] if z['kind']=='typed-seam-joint');inst['kind']='pretend-native-architecture';bind_pair(d)
test('shared_bridge_disguised_as_native_architecture',d,pair)

d=read('C100-047');d['bridge_cells']+=1
for side in ('left','right'):d[side]['metrics']['foreign_bridge_cells']+=1
bind_pair(d)
test('false_bridge_cell_count_with_recomputed_digests',d,pair)

report={'result':'PASS','mutations':results,'count':len(results),'retained_native_files_modified':False,
        'test_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'auditor_sha256':hashlib.sha256(Path(a.__file__).read_bytes()).hexdigest()}
(OUT/'tamper-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS '+str(len(results))+' independent corruptions detected',flush=True)
