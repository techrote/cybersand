#!/usr/bin/env python3
"""Adversarial copied-data/model tests; no native World or Rapier execution."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
import sol_authority_model as m

ROOT=Path(__file__).resolve().parents[2]
HISTORICAL=ROOT/'docs/audits/sol-authority-20261105/historical-excerpts.json'

def synthetic_capture():
    source=m.canonical()['original'];members=[source['members'][i:i+6] for i in range(0,len(source['members']),6)]
    rects=[source['rectangles'][i:i+4] for i in range(0,len(source['rectangles']),4)]
    pose=[1,0,0,1]+source['center'];mass=source['mass'];inertia=70453.6484375
    stamp=dict(run='offline-run-1',world='world-1',body='aggregate-1',generation=1,epoch=1,tick=0,sample=1,mutation_serial=0,body_serial=0,mask_serial=0,actual_step=0,
        native_source_sha256=m.NATIVE_INPUT_SHA,native_runtime_sha256=sorted(m.RUNTIMES)[0],material_lock_sha256='8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc',
        payload_sha256=m.digest(members),shape_sha256=m.digest(rects),body_state_sha256=m.digest([pose,[0,0],0,mass,inertia]))
    positions={(r[0],r[1]) for r in members}
    census=[dict(cell=[x,y],tuple=[0,0,0,200],resident=True,hot=False,source_owner=stamp['world'],mask_owner=stamp['body'] if (x,y) in positions else None) for y in range(26,66) for x in range(43,74)]
    return dict(schema='SOL-OFFLINE-CAPTURE-001',origin='synthetic-copied-values',capture_scope='current-pose-noop',mask_policy='synthetic-cell-centre-001',world_health='HEALTHY',identity=stamp,members=members,rectangles=rects,
        stored_com=source['center'],mass=mass,geometric_inertia=source['inertia'],body_inertia=inertia,pose=pose,velocity=[0,0],omega=0,footprint=[43,26,31,40],census=census)

class CaptureTests(unittest.TestCase):
    def test_complete_synthetic_is_never_authority(self):
        packet=synthetic_capture();before=m.encoded(packet);r=m.validate_capture(packet)
        self.assertEqual(r['status'],'COMPLETE_FOR_NOOP_MODEL');self.assertFalse(r['live_authority']);self.assertFalse(r['actuation_permitted'])
        self.assertEqual(r['census_cells'],1240);self.assertEqual(before,m.encoded(packet))
        self.assertEqual((r['native_mutations'],r['rid_calls'],r['generated_work']),(0,0,0))
        self.assertFalse(any(v['cell'] in [[60,32],[68,50]] and v['mask_owner'] for v in packet['census']))

    def test_sixteen_capture_corruptions_refuse(self):
        source=synthetic_capture()
        changes=[lambda d:d['members'][0].__setitem__(0,60),lambda d:d['members'].pop(),lambda d:d['rectangles'][0].__setitem__(2,30),
            lambda d:d['census'].pop(),lambda d:d['census'].__setitem__(1,copy.deepcopy(d['census'][0])),lambda d:d['census'][0]['tuple'].pop(),
            lambda d:d['census'][0].__setitem__('resident',False),lambda d:d['census'][0].__setitem__('hot',True),
            lambda d:d['census'][0].__setitem__('source_owner','foreign'),lambda d:d['census'][0].__setitem__('mask_owner','foreign'),
            lambda d:d['census'][0]['tuple'].__setitem__(0,3),lambda d:d['census'][0]['tuple'].__setitem__(3,201),
            lambda d:d['identity'].__setitem__('native_source_sha256','0'*64),lambda d:d['identity'].__setitem__('native_runtime_sha256','0'*64),
            lambda d:d['pose'].__setitem__(0,float('nan')),lambda d:d.__setitem__('capture_scope','swept-move')]
        for index,change in enumerate(changes):
            packet=copy.deepcopy(source);change(packet)
            with self.subTest(corruption=index):self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')

    def test_unsupported_masked_native_material_refuses(self):
        packet=synthetic_capture();cell=next(v for v in packet['census'] if v['mask_owner'])
        cell['tuple'][0]=43;self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')
        cell['tuple'][0]=0;cell['mask_owner']=None;self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')

    def test_overflow_unknown_fields_and_optimized_python_refuse(self):
        packet=synthetic_capture();packet['census']=[packet['census'][0]]*(m.MAX_CENSUS+1)
        self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')
        packet=synthetic_capture();packet['eligible']=True;self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')
        env=os.environ.copy();env['PYTHONPATH']=str(ROOT/'tools/experiments')
        result=subprocess.run([sys.executable,'-O','-c','import sol_authority_model'],env=env,capture_output=True)
        self.assertNotEqual(result.returncode,0);self.assertIn(b'optimized Python is refused',result.stderr)

    def test_genuine_historical_hard_negatives_and_missing_rotated_authority(self):
        data=json.loads(HISTORICAL.read_text(encoding='utf-8'));control=data['interior_control']
        r=m.hard_probe(control['geometry']['proxies'],data['native_fields'][control['native_field']])
        self.assertEqual(r['status'],'REFUSED_HARD_GEOMETRY')
        # Full frozen field also contains512perimeter Wall cells outside this body.
        self.assertEqual((r['material_counts']['2'],r['material_counts']['1']),(9,528))
        self.assertEqual(len({tuple(v['cell']) for v in r['hard_intersections']}),16)
        stationary=data['negative_cases']['embedded_stationary'];g=data['geometries'][str(stationary['initial']['measurement']['geometry_id'])]
        r=m.hard_probe(g['proxies'],data['native_fields'][stationary['native_field']])
        witness=next(v for v in r['hard_intersections'] if v['cell']==[53,67] and v['proxy']==6)
        self.assertEqual(witness['material'],43);self.assertGreater(witness['area'],1e-9);self.assertLess(witness['area'],1e-7)
        rotated=data['negative_cases']['rotated_compound'];g=data['geometries'][str(rotated['initial']['measurement']['geometry_id'])]
        self.assertNotEqual(rotated['initial']['state']['pose'],g['pose'])
        self.assertEqual(m.validate_capture(rotated)['status'],'REFUSED_OR_UNKNOWN')
        self.assertFalse(r['live_authority']);self.assertFalse(r['actuation_permitted'])

    def test_source_map_and_input_custody(self):
        folder=HISTORICAL.parent;custody=json.loads((folder/'input-custody.json').read_text(encoding='utf-8'))
        for item in custody['artifacts']:
            self.assertEqual(hashlib.sha256((folder/item['public_file']).read_bytes()).hexdigest(),item['public_lf_sha256'])
        data=json.loads((folder/'source-map.json').read_text(encoding='utf-8'));rows={r['path']:r for r in data['files']}
        self.assertEqual((data['file_count'],data['native_input_union_count']),(1355,92))
        self.assertEqual({r['path'] for r in data['files'] if r['classification']=='protected-conflict'}, {'native/src/world.cpp','native/src/world_inertial.inc','native/src/world_pressure.inc'})
        for label,source in data['sources'].items():
            for transition in source['material']['reviewed_transitions']:
                self.assertIsNotNone(rows[transition['record']]['sources'][label])
            for platform,inventory in data['runtime_inventories'][label].items():
                self.assertTrue(set(inventory['native_inputs'])<=set(rows));self.assertTrue(set(inventory['build_inputs'])<=set(rows))
        self.assertIsNone(data['composed_tree']);self.assertFalse(data['admitted']);self.assertFalse(data['live_authority']);self.assertFalse(data['actuation_permitted'])

class LeaseTests(unittest.TestCase):
    def setUp(self):self.packet=synthetic_capture();self.stamp=self.packet['identity'];self.model=m.LeaseModel()
    def grant(self,now=0):self.assertTrue(self.model.event('grant',now,stamp=self.stamp)['accepted'])
    def test_body_aliases_source_rebinding_and_generation_cannot_renew(self):
        for terminal in [False,True]:
            self.model=m.LeaseModel();self.grant();self.model.event('simulate_partial_fault' if terminal else 'cancel',1)
            for field in ['run','body','generation','payload_sha256','shape_sha256','native_source_sha256','native_runtime_sha256']:
                changed=copy.deepcopy(self.stamp);changed['actual_step']=1
                changed[field]=changed[field]+1 if type(changed[field]) is int else ('aggregate-2' if field=='body' else '0'*64)
                self.assertFalse(self.model.event('grant',2,stamp=changed)['accepted'])
            self.assertEqual(self.model.snapshot()['consumed_leases'],1)

    def test_trace_capacity_retires_even_an_expired_active_lease(self):
        for now,expected in [(0,'MODEL_CAPACITY_FAILURE'),(100,'EXPIRED')]:
            self.model=m.LeaseModel();self.grant()
            for _ in range(m.MAX_EVENTS-1):self.model.event('tick',0)
            self.assertFalse(self.model.event('release',now,stamp=self.stamp)['accepted'])
            self.assertEqual(self.model.state,expected);self.assertIsNone(self.model.active)
            self.assertEqual(self.model.snapshot()['consumed_leases'],1)

    def test_failed_world_capture_and_deadline_integer_capacity_refuse(self):
        packet=copy.deepcopy(self.packet);packet['world_health']='FAILED'
        self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')
        self.assertFalse(self.model.event('grant',2**63-1,stamp=self.stamp)['accepted'])
        self.assertEqual(self.model.snapshot()['consumed_leases'],0)

    def test_late_partial_failure_is_terminal_after_expiry(self):
        for explicit_expiry in [False,True]:
            self.model=m.LeaseModel();self.grant()
            if explicit_expiry:self.model.event('capture',33,stamp=self.stamp,packet=self.packet)
            self.assertTrue(self.model.event('simulate_partial_fault',34,stamp=self.stamp)['accepted'])
            changed=copy.deepcopy(self.stamp);changed['actual_step']=1
            self.assertFalse(self.model.event('grant',35,stamp=changed)['accepted']);self.assertEqual(self.model.state,'MODEL_TERMINAL_FAILURE')

    def test_progress_never_rewinds_and_boolean_identity_aliases_refuse(self):
        for field in ['mutation_serial','body_serial','mask_serial']:
            self.model=m.LeaseModel();first=copy.deepcopy(self.stamp);first[field]=10
            self.assertTrue(self.model.event('grant',0,stamp=first)['accepted']);self.model.event('cancel',1)
            changed=copy.deepcopy(first);changed['actual_step']=1;changed[field]=9
            self.assertFalse(self.model.event('grant',2,stamp=changed)['accepted'])
        self.model=m.LeaseModel();self.grant();changed=copy.deepcopy(self.stamp);changed['generation']=True;changed['actual_step']=False
        self.assertFalse(self.model.event('capture',1,stamp=changed,packet=self.packet)['accepted'])

    def test_deadline_is_inclusive_and_scope_is_bounded_before_encoding(self):
        self.grant();self.assertTrue(self.model.event('capture',m.LEASE_EVENTS,stamp=self.stamp,packet=self.packet)['accepted'])
        self.model=m.LeaseModel();self.grant();self.assertFalse(self.model.event('capture',m.LEASE_EVENTS+1,stamp=self.stamp,packet=self.packet)['accepted'])
        packet=copy.deepcopy(self.packet);packet['schema']=['X']*10000
        self.assertEqual(m.validate_capture(packet)['status'],'REFUSED_OR_UNKNOWN')
    def test_full_noop_lifecycle_and_duplicate_replay(self):
        self.grant();digest=hashlib.sha256(m.encoded(self.packet)).hexdigest()
        for kind,now in [('capture',1),('main_validate',2),('noop_ack',3),('release',4)]:
            self.assertTrue(self.model.event(kind,now,stamp=self.stamp,packet=self.packet,capture_digest=digest)['accepted'])
        self.assertFalse(self.model.event('grant',5,stamp=self.stamp)['accepted']);snapshot=self.model.snapshot()
        self.assertEqual((snapshot['state'],snapshot['consumed_leases']),('RELEASED',1))
        self.assertEqual((snapshot['native_mutations'],snapshot['rid_calls'],snapshot['generated_work']),(0,0,0))

    def test_mutation_events_refuse_without_losing_hold(self):
        self.grant()
        for kind in ['tick','prepare','emission','paint','relocate','reset','replacement','teardown']:
            self.assertFalse(self.model.event(kind,1)['accepted']);self.assertEqual(self.model.state,'HELD')
        self.assertEqual(self.model.snapshot()['attempts'],9)

    def test_cancel_expiry_sample_and_epoch_never_refund_step(self):
        for operation,now in [('cancel',1),('capture',33)]:
            self.model=m.LeaseModel();self.grant();self.model.event(operation,now,stamp=self.stamp,packet=self.packet)
            for field in ['sample','epoch','mutation_serial']:
                altered=copy.deepcopy(self.stamp);altered[field]+=1
                self.assertFalse(self.model.event('grant',34,stamp=altered)['accepted'])
            self.assertEqual(self.model.snapshot()['consumed_leases'],1)

    def test_ABA_actual_step_and_wrong_identity_invalidate(self):
        for field in ['mutation_serial','body_serial','mask_serial','actual_step','epoch','sample','payload_sha256','shape_sha256','world','body']:
            self.model=m.LeaseModel();self.grant();altered=copy.deepcopy(self.stamp)
            altered[field]=altered[field]+1 if isinstance(altered[field],int) else '0'*64
            self.assertFalse(self.model.event('capture',1,stamp=altered,packet=self.packet)['accepted']);self.assertEqual(self.model.state,'INVALIDATED')
            self.assertFalse(self.model.event('grant',2,stamp=self.stamp)['accepted'])

    def test_bad_capture_wrong_ACK_and_reordered_release(self):
        self.grant();self.assertFalse(self.model.event('release',1,stamp=self.stamp)['accepted'])
        self.assertTrue(self.model.event('capture',2,stamp=self.stamp,packet=self.packet)['accepted'])
        self.assertFalse(self.model.event('noop_ack',3,stamp=self.stamp,capture_digest='0'*64)['accepted'])
        self.assertFalse(self.model.event('main_validate',4,stamp=self.stamp,capture_digest='0'*64)['accepted']);self.assertEqual(self.model.state,'INVALIDATED')
        self.model=m.LeaseModel();self.grant();bad=copy.deepcopy(self.packet);bad['census'].pop()
        self.assertFalse(self.model.event('capture',1,stamp=self.stamp,packet=bad)['accepted']);self.assertEqual(self.model.state,'REFUSED_CAPTURE')

    def test_partial_failure_terminal_and_explicit_retirement(self):
        self.grant();self.assertTrue(self.model.event('simulate_partial_fault',1)['accepted'])
        for kind in ['release','cancel','noop_ack','reset','capture']:
            self.assertFalse(self.model.event(kind,2,stamp=self.stamp,packet=self.packet)['accepted'])
        for field in ['sample','epoch','actual_step','generation']:
            altered=copy.deepcopy(self.stamp);altered[field]+=1;self.assertFalse(self.model.event('grant',3,stamp=altered)['accepted'])
        self.assertTrue(self.model.event('retire',4)['accepted']);self.assertFalse(self.model.event('grant',5,stamp=self.stamp)['accepted'])
        altered=copy.deepcopy(self.stamp);altered['world']='world-2';self.assertTrue(self.model.event('grant',6,stamp=altered)['accepted'])

    def test_capacity_preserves_consumption_and_trace_denominators(self):
        for step in range(m.MAX_LEASES):
            stamp=copy.deepcopy(self.stamp);stamp['actual_step']=step
            self.assertTrue(self.model.event('grant',step*2,stamp=stamp)['accepted']);self.assertTrue(self.model.event('cancel',step*2+1)['accepted'])
        stamp['actual_step']+=1;self.assertFalse(self.model.event('grant',20,stamp=stamp)['accepted']);self.assertEqual(self.model.snapshot()['consumed_leases'],m.MAX_LEASES)
        self.model=m.LeaseModel();self.grant()
        for _ in range(m.MAX_EVENTS):self.model.event('tick',0)
        snapshot=self.model.snapshot();self.assertEqual((snapshot['attempts'],len(snapshot['trace']),snapshot['trace_overflow']),(257,256,1))

    def test_copied_identity_trace_immutability_and_clock(self):
        self.grant(5);original=copy.deepcopy(self.stamp);self.stamp['sample']+=1
        self.assertFalse(self.model.event('capture',4,stamp=original,packet=self.packet)['accepted'])
        self.packet['identity']=original;self.assertTrue(self.model.event('capture',6,stamp=original,packet=self.packet)['accepted'])
        snapshot=self.model.snapshot();snapshot['trace'][0]['state']='poison'
        self.assertEqual(self.model.snapshot()['trace'][0]['state'],'HELD')

if __name__=='__main__':unittest.main()
