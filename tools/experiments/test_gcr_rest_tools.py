import json,tempfile,unittest
from pathlib import Path
from gcr_rest_manifest import manifest
from analyze_gcr_rest import reduce_capture,energy_summary,summarize
class RestTools(unittest.TestCase):
    def test_population_and_shared_windows(self):
        p=manifest();self.assertEqual(len(p['cases']),44);self.assertEqual(p['maximum_captures'],88)
        shared=[r for r in p['cases'] if r['comparison']=='full520' and r['mode']=='control' and r['budget']==20]
        self.assertEqual(len(shared),1);self.assertEqual(shared[0]['ticks'],1800)
        self.assertEqual(p['drive']['schedule'],[[600,660,.02],[900,906,2.0]])
    def test_failed_is_not_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'failed.json';p.write_text('{"ok":false,"rows":[{}]}')
            v=reduce_capture(p);self.assertEqual(v['status'],'failed');self.assertIsNone(v['metrics'])
    def test_empty_is_not_rest(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'empty.json';p.write_text('{"ok":true,"rows":[]}')
            self.assertEqual(reduce_capture(p)['status'],'failed')
    def test_energy_closure_is_independently_calculated(self):
        a={'actual_mass':2,'actual_inertia':3,'velocity_before_correction':[1,2],'omega_before_correction':1,
           'kinetic_before_correction':6.5,'velocity_after_zeroing':[1,2],'omega_after_zeroing':1,'kinetic_after_zeroing':6.5,
           'velocity_after_wrench':[0,0],'omega_after_wrench':0,'kinetic_after_wrench':0,'catch_applied':True,
           'uncaught_counterfactual_kinetic':1.25,'catch_removed_energy':1.25}
        result=energy_summary([a]);self.assertEqual(result['maximum_kinetic_field_error'],0);self.assertEqual(result['maximum_catch_removed_closure_error'],0)
        a['kinetic_after_wrench']=3
        result=energy_summary([a]);self.assertEqual(result['maximum_kinetic_field_error'],3);self.assertEqual(result['maximum_catch_removed_closure_error'],3)
    def test_proposed_quiet_but_refused_application_is_not_rest(self):
        raw={'ok':True,'case':{'kind':'barrel'}}
        row={'out':[0,0,0,0,0,0],'vertical_depth':0,'post_overlap':0,'rest_context':{'hard_clearance':True},'gcr':{},
             'rest_receipt':{'session':7,'bodies':[{'id':1,'sample':1,'session':7,'quiet_admitted':True}]},
             'application':{'accepted':False,'bodies':[]}}
        result=summarize(raw,[row]*300)
        self.assertIsNone(result['rest_gate']);self.assertEqual(result['rest_scope'],'NO_QUALIFIED_REST_WINDOW')
        row['application']={'accepted':True,'bodies':[{'index':0,'session':8,'sample':1}]}
        self.assertIsNone(summarize(raw,[row]*300)['rest_gate'])
        row['application']['bodies'][0]['session']=7
        self.assertTrue(summarize(raw,[row]*300)['rest_gate'])
    def test_missing_energy_is_not_zero_dissipation(self):
        result=energy_summary([{}])
        self.assertIsNone(result['zeroing_removed_energy_sum']);self.assertIsNone(result['catch_removed_energy_sum'])
if __name__=='__main__':unittest.main()
