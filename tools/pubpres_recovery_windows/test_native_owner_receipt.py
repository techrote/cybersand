"""Receipt-only adversaries; synthetic fixtures cannot grant native execution."""
import copy
import json
import unittest

from native_owner_receipt import PREFIX,validate


class MountedNativeReceipt(unittest.TestCase):
    def setUp(self):
        self.identity={'source':'a'*40,'test_sha':'b'*64,'engine_sha':'c'*64,
            'native_sha':'d'*64,'native_descriptor_sha':'e'*64,'platform':'Windows'}
        def state(mode,empty=False):return {'schema':'PUBPRES-TASK-COMPLETION-V1','mode':mode,
            'completed_dispatches':0 if empty else 36,'completed_tasks':0 if empty else 132}
        self.receipt={'schema':'pubpres-task-completion-native-v1','checks':150,'failures':[],
            'source_revision':self.identity['source'],'test_sha256':self.identity['test_sha'],
            'engine_sha256':self.identity['engine_sha'],'native_sha256':self.identity['native_sha'],
            'native_descriptor_sha256':self.identity['native_descriptor_sha'],'platform':'Windows','process_id':123,
            'native_resource':'res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
            'observations':[{'stage':'matched_native','control':state('all_workers'),'candidate':state('actual_tasks'),
                'control_completed_tick':32,'candidate_completed_tick':32,'physical_hash':'1'*16},
                *[{'stage':'prepared_owner','enabled':enabled,'before':state(mode,True),'after':state(mode),
                   'completed_tick':8,'physical_hash':'2'*16} for enabled,mode in ((False,'all_workers'),(True,'actual_tasks'))],
                *[{'stage':'refused_selector','type':kind,'error':'Native selector must be boolean'} for kind in (2,3,4)]]}
        self.text=PREFIX+json.dumps({'checks':150,'failures':[]})+'\n'

    def test_reference_reader_shape_and_exact_terminal(self):
        self.assertEqual(validate(self.receipt,self.text,**self.identity)['checks'],150)
        for text in ('',self.text+self.text,self.text.replace('150','149')):
            with self.subTest(text=text),self.assertRaises(ValueError):validate(self.receipt,text,**self.identity)

    def test_unexecuted_tasks_omitted_turns_and_predecessor_credit_refused(self):
        mutations=(
            lambda d:d['observations'][0]['candidate'].__setitem__('completed_dispatches',0),
            lambda d:d['observations'][0].__setitem__('candidate_completed_tick',31),
            lambda d:d['observations'][1]['before'].__setitem__('completed_tasks',132),
            lambda d:d['observations'][1].__setitem__('completed_tick',7),
            lambda d:d['observations'][2].__setitem__('physical_hash','3'*16),
            lambda d:d['observations'][0]['candidate'].__setitem__('mode','all_workers'),
            lambda d:d['observations'][0]['candidate'].__setitem__('completed_tasks',True))
        for mutate in mutations:
            altered=copy.deepcopy(self.receipt);mutate(altered)
            with self.assertRaises(ValueError):validate(altered,self.text,**self.identity)

    def test_missing_or_duplicate_world_and_refusal_observations_refused(self):
        for index in range(6):
            altered=copy.deepcopy(self.receipt);altered['observations'][index]=copy.deepcopy(altered['observations'][(index+1)%6])
            with self.subTest(index=index),self.assertRaises(ValueError):validate(altered,self.text,**self.identity)

    def test_engine_native_descriptor_or_fixture_substitution_refused(self):
        for key in ('source_revision','test_sha256','engine_sha256','native_sha256','native_descriptor_sha256','native_resource','platform'):
            altered=copy.deepcopy(self.receipt);altered[key]='wrong'
            with self.subTest(key=key),self.assertRaises(ValueError):validate(altered,self.text,**self.identity)


if __name__=='__main__':unittest.main()
