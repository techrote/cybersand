import json,tempfile,unittest
from pathlib import Path
from gcr_rest_manifest import manifest
from analyze_gcr_rest import reduce_capture,energy_summary,summarize,configuration_receipts
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
        self.assertFalse(result['delivered_wrench_measurement_complete'])
        self.assertIsNone(result['maximum_delivered_delta_v_error']);self.assertIn('impulse',result['missing_field_observations'])
    def test_native_configuration_mismatch_is_failed_not_qualified(self):
        case={'id':'unit','kind':'barrel','mode':'PRC','budget':40}
        raw={'ok':True,'case':case,'rows':[{'rest_receipt':{'version':1,'mode':'PRC','base_budget':20}}]}
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'mismatch.json';path.write_text(json.dumps(raw))
            reduced=reduce_capture(path,case)
            self.assertEqual(reduced['status'],'failed');self.assertIsNone(reduced['metrics'])
            self.assertIn('native_budget_mismatch',reduced['native_configuration']['refusals'])
        raw['rows'][0]['rest_receipt']['base_budget']=40
        self.assertTrue(configuration_receipts(raw,case)['ok'])
        raw['rows'][0]['rest_receipt']['mode']='control'
        self.assertFalse(configuration_receipts(raw,case)['ok'])
    def test_nonactionable_gap_does_not_prove_or_disprove_configuration(self):
        case={'id':'unit','kind':'barrel','mode':'control','budget':20}
        raw={'case':case,'rows':[{}, {'rest_receipt':{'version':1,'mode':'control','base_budget':20}}]}
        proof=configuration_receipts(raw,case)
        self.assertTrue(proof['ok']);self.assertEqual(proof['native_receipt_coverage'],.5)
        self.assertEqual(proof['nonactionable_no_result_observations'],1)
        raw['rows'][0]['application']={'accepted':True}
        self.assertFalse(configuration_receipts(raw,case)['ok'])
        raw['rows']=[{}]
        self.assertFalse(configuration_receipts(raw,case)['ok'])
    def test_delivered_wrench_closure_is_independent_of_energy_arithmetic(self):
        a={'actual_mass':2,'actual_inertia':3,'velocity_before_correction':[1,2],'omega_before_correction':1,
           'kinetic_before_correction':6.5,'velocity_after_zeroing':[1,2],'omega_after_zeroing':1,'kinetic_after_zeroing':6.5,
           'velocity_after_wrench':[0,0],'omega_after_wrench':0,'kinetic_after_wrench':0,'impulse':[-2,-4],'angular_impulse':-3,
           'zeroing_removed_energy':0,'correction_potential_delta':0,'catch_applied':True,
           'uncaught_impulse':[-1,-2],'uncaught_angular_impulse':0,'catch_delta_impulse':[-1,-2],'catch_delta_angular_impulse':-3,
           'uncaught_counterfactual_kinetic':2.75,'catch_removed_energy':2.75}
        proof=energy_summary([a])
        self.assertTrue(proof['delivered_wrench_measurement_complete'])
        self.assertEqual(proof['maximum_delivered_delta_v_error'],0);self.assertEqual(proof['maximum_delivered_delta_omega_error'],0)
        self.assertEqual(proof['maximum_catch_counterfactual_kinetic_field_error'],0)
        # Reported energy subtraction remains exact even with a missing force.
        a['impulse']=[0,0];a['angular_impulse']=0
        proof=energy_summary([a])
        self.assertEqual(proof['maximum_catch_removed_closure_error'],0)
        self.assertAlmostEqual(proof['maximum_delivered_delta_v_error'],5**.5)
        self.assertEqual(proof['maximum_delivered_delta_omega_error'],1)
    def test_nonfinite_and_negative_catch_energy_are_explicit(self):
        a={'actual_mass':2,'actual_inertia':3,'velocity_before_correction':[0,0],'omega_before_correction':0,'kinetic_before_correction':0,
           'velocity_after_zeroing':[0,0],'omega_after_zeroing':0,'kinetic_after_zeroing':0,
           'velocity_after_wrench':[1,0],'omega_after_wrench':0,'kinetic_after_wrench':1,
           'impulse':[float('nan'),0],'angular_impulse':0,'zeroing_removed_energy':0,'correction_potential_delta':0,
           'catch_applied':True,'uncaught_impulse':[0,0],'uncaught_angular_impulse':0,'catch_delta_impulse':[2,0],
           'catch_delta_angular_impulse':0,'uncaught_counterfactual_kinetic':0,'catch_removed_energy':-1}
        proof=energy_summary([a])
        self.assertFalse(proof['delivered_wrench_measurement_complete'])
        self.assertEqual(proof['nonfinite_or_malformed_field_observations']['impulse'],1)
        self.assertEqual(proof['negative_catch_removed_energy_samples'],1)
        self.assertEqual(proof['negative_independently_calculated_catch_removed_energy_samples'],1)
if __name__=='__main__':unittest.main()
