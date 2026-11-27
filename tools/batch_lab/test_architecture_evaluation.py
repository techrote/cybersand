"""Adversarial material/context reducer tests, explicitly synthetic."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from evaluate_architecture import contextual_metrics, reduce_manifest


def fixture():
    width=32;height=24
    before=[0]*(width*height)
    for x in range(2,30):before[8*width+x]=58
    after=before.copy()
    for x in range(6,10):after[7*width+x]=62
    context={'structural_materials':[58],'detail_materials':[62], 'anchor_rects':[[2,8,28,1]],
             'clearance_rects':[[0,12,32,8]],'detail_zones':[{'rect':[2,4,28,5],'minimum_fraction':0.01,'maximum_fraction':0.2}],
             'protection_rects':[[0,0,2,24]],'route':[[2,16],[29,16]],'clearance_radius':2}
    return before,after,context


def case(identifier='test',arm='hand_typed'):
    before,after,context=fixture()
    def record(cells):
        raw=struct.pack('<768H',*cells)
        return {'base64':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest(),'encoding':'u16le'}
    return {'id':identifier,'family':'hangar','arm':arm,'seed':37901,'extent':[32,24], 'before':record(before),'after':record(after),
            'status':'completed','recipe_sha256':'a'*64,'context':context,
            'receipts':[{'backend':'CyberNativeCellWorld','status':'completed','requested':4,'checked':4,'changed':4,
                         'unchanged':0,'confirmed':4,'excluded':0,'refused':0}]}


def manifest(cases):
    return {'schema_version':'cybersand.architectural-native-experiment.v1','source_commit':'b'*40,
            'runtime':{'bridge_sha256':'c'*64},'cases':cases}


class ArchitectureTests(unittest.TestCase):
    def test_supported_detail_has_actual_face_contacts(self):
        before,after,context=fixture();m=contextual_metrics([32,24],before,after,context)
        self.assertTrue(m['contextual_detail_checks_pass']);self.assertEqual(m['new_detail_cells'],4)
        self.assertEqual(m['declared_anchor_contact_cells'],4);self.assertEqual(m['unanchored_detail_components'],0)

    def test_equal_cell_random_valid_does_not_get_context_credit(self):
        before,after,context=fixture(); random=before.copy()
        for x in range(6,10):random[3*32+x]=62
        good=contextual_metrics([32,24],before,after,context);bad=contextual_metrics([32,24],before,random,context)
        self.assertEqual(good['new_detail_cells'],bad['new_detail_cells'])
        self.assertEqual(good['empty_fraction'],bad['empty_fraction'])
        self.assertFalse(bad['contextual_detail_checks_pass']);self.assertEqual(bad['unanchored_detail_cells'],4)
        self.assertEqual(bad['detail_outside_declared_zones'],4)

    def test_anchor_box_without_native_structure_is_not_a_support(self):
        before,after,context=fixture();context['anchor_rects']=[[2,1,28,1]]
        m=contextual_metrics([32,24],before,after,context)
        self.assertEqual(m['declared_anchor_structural_cells'],0);self.assertFalse(m['contextual_detail_checks_pass'])

    def test_touching_any_host_is_not_touching_declared_face(self):
        before,after,context=fixture();context['anchor_rects']=[[20,8,4,1]]
        m=contextual_metrics([32,24],before,after,context)
        self.assertEqual(m['detached_detail_cells'],0);self.assertEqual(m['unanchored_detail_cells'],4)

    def test_clearance_violation_and_protection_change_are_measured(self):
        before,after,context=fixture();after[16*32+1]=62
        m=contextual_metrics([32,24],before,after,context)
        self.assertEqual(m['new_clearance_intrusion_cells'],1);self.assertEqual(m['protected_changed_cells'],1)
        self.assertFalse(m['contextual_detail_checks_pass'])

    def test_dense_anchor_paint_is_not_automatically_good(self):
        before,after,context=fixture()
        for y in range(4,8):
            for x in range(2,30):after[y*32+x]=62
        m=contextual_metrics([32,24],before,after,context)
        self.assertFalse(m['detail_zone_envelopes'][0]['within_envelope']);self.assertFalse(m['contextual_detail_checks_pass'])

    def test_empty_detail_is_unassessed(self):
        before,_,context=fixture();m=contextual_metrics([32,24],before,before,context)
        self.assertFalse(m['context_assessable']);self.assertIsNone(m['contextual_detail_checks_pass'])

    def test_overlapping_material_roles_refuse(self):
        before,after,context=fixture();context['detail_materials']=[58]
        with self.assertRaisesRegex(ValueError,'disjoint'):contextual_metrics([32,24],before,after,context)

    def test_context_bounds_and_nonfinite_density_refuse(self):
        for field,value in [('anchor_rects',[[-1,0,4,4]]),('clearance_rects',[[0,0,999,1]]),('detail_zones',[{'rect':[0,0,1,1],'maximum_fraction':float('nan')}])]:
            before,after,context=fixture();context[field]=value
            with self.assertRaises(ValueError):contextual_metrics([32,24],before,after,context)

    def test_exact_native_receipts_and_hashes_admitted(self):
        r=reduce_manifest(manifest([case()]),Path('.'))
        self.assertEqual(r['evaluable_attempts'],1);self.assertEqual(r['native_completed_attempts'],1)

    def test_queued_missing_wrong_hash_or_unacknowledged_readbacks_remain_failures(self):
        mutations=[lambda x:x['receipts'][0].update(status='queued'), lambda x:x['receipts'][0].update(backend='visual-preview'),
                   lambda x:x['after'].update(sha256='0'*64), lambda x:x['receipts'][0].update(changed=3,confirmed=3,excluded=1)]
        cases=[]
        for i,mutate in enumerate(mutations):
            c=case(str(i));mutate(c);c['seed']+=i;cases.append(c)
        r=reduce_manifest(manifest(cases),Path('.'))
        self.assertEqual(r['total_attempts'],4);self.assertEqual(r['evaluable_attempts'],0)

    def test_partial_confirmed_prefix_is_evaluable_not_completed(self):
        c=case();c['status']='partial';r=reduce_manifest(manifest([c]),Path('.'))
        self.assertEqual(r['evaluable_attempts'],1);self.assertEqual(r['native_completed_attempts'],0)

    def test_missing_registered_cases_are_not_silently_removed(self):
        reg={'families':['hangar'],'arms':['hand_typed','random_valid'],'seeds':[37901,37917]}
        r=reduce_manifest(manifest([case()]),Path('.'),reg)
        self.assertEqual(len(r['missing_registered_cases']),3)

    def test_duplicate_source_attempts_retained_as_unevaluable(self):
        r=reduce_manifest(manifest([case(),case()]),Path('.'))
        self.assertEqual(r['total_attempts'],2);self.assertEqual(r['evaluable_attempts'],1)

    def test_changed_context_breaks_matched_comparison(self):
        a=case();b=case('random','random_valid');b['context']['anchor_rects']=[[3,8,27,1]]
        r=reduce_manifest(manifest([a,b]),Path('.'))
        self.assertFalse(r['matched_blocks'][0]['matched_context'])

    def test_no_model_arm_or_unknown_inference_promoted(self):
        c=case(arm='model_assisted');r=reduce_manifest(manifest([c]),Path('.'))
        self.assertEqual(r['evaluable_attempts'],0);self.assertFalse(r['model_assisted']['qualified'])

    def test_malformed_case_remains_visible_without_reducer_crash(self):
        r=reduce_manifest(manifest([None,case()]),Path('.'))
        self.assertEqual(r['total_attempts'],2);self.assertEqual(r['evaluable_attempts'],1)
        self.assertEqual(r['attempts'][0]['reason'],'Case is not an object')

    def test_plane_path_escape_refuses(self):
        c=case();c['before']={'path':'../outside.bin','sha256':'a'*64}
        r=reduce_manifest(manifest([c]),Path('.'))
        self.assertIn('within the evidence directory',r['attempts'][0]['reason'])

if __name__=='__main__':unittest.main()
