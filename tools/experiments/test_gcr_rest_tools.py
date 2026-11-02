import copy,json,tempfile,unittest
from pathlib import Path
from gcr_rest_manifest import manifest
from analyze_gcr_rest import reduce_capture,energy_summary,summarize,configuration_receipts,compound_conservation
class RestTools(unittest.TestCase):
    def fresh_rows(self,row,count=300):
        rows=[]
        for i in range(count):
            current=copy.deepcopy(row);current['tick']=i
            current['application']['snapshot']=i+1
            current['application_step']={'version':1,'physics_call':i,'snapshot_before':i,'snapshot_after':i+1,'delivered_this_step':True}
            rows.append(current)
        return rows
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
        result=summarize(raw,self.fresh_rows(row))
        self.assertIsNone(result['rest_gate']);self.assertEqual(result['rest_scope'],'NO_QUALIFIED_REST_WINDOW')
        row['application']={'accepted':True,'bodies':[{'index':0,'session':8,'sample':1,'age':0}]}
        self.assertIsNone(summarize(raw,self.fresh_rows(row))['rest_gate'])
        row['application']['bodies'][0]['session']=7
        self.assertTrue(summarize(raw,self.fresh_rows(row))['rest_gate'])
    def test_stale_accepted_application_cannot_qualify_quiet_rest(self):
        raw={'ok':True,'case':{'kind':'barrel'}}
        row={'out':[0,0,0,0,0,0],'vertical_depth':0,'post_overlap':0,'rest_context':{'hard_clearance':True},'gcr':{},
             'quiet_admitted_current':True,'rest_receipt':{'session':7,'bodies':[{'id':1,'sample':1,'session':7,'quiet_admitted':True}]},
             'application':{'accepted':True,'bodies':[{'index':0,'session':7,'sample':1,'age':1}]}}
        proof=summarize(raw,self.fresh_rows(row))
        self.assertIsNone(proof['rest_gate']);self.assertEqual(proof['quiet_admitted_observations'],0)
        row['application']['bodies'][0]['age']=0
        self.assertTrue(summarize(raw,self.fresh_rows(row))['rest_gate'])
        row['application']['bodies']*=2
        self.assertIsNone(summarize(raw,self.fresh_rows(row))['rest_gate'])
    def test_repeated_age0_snapshot_is_not_current_quiet_contact(self):
        raw={'ok':True,'case':{'kind':'barrel'}}
        row={'out':[0,0,0,0,0,0],'vertical_depth':0,'post_overlap':0,'rest_context':{'hard_clearance':True},'gcr':{},
             'quiet_admitted_current':True,'rest_receipt':{'session':7,'bodies':[{'id':1,'sample':1,'session':7,'quiet_admitted':True}]},
             'application':{'accepted':True,'bodies':[{'index':0,'session':7,'sample':1,'age':0}]}}
        rows=self.fresh_rows(row)
        self.assertTrue(summarize(raw,rows)['rest_gate'])
        for i,current in enumerate(rows):
            current['application']['snapshot']=1
            current['application_step']={'version':1,'physics_call':i,'snapshot_before':1,'snapshot_after':1,'delivered_this_step':True}
        result=summarize(raw,rows)
        self.assertIsNone(result['rest_gate']);self.assertEqual(result['fresh_application_observations'],0)
        # A falsely copied increasing-transition hint still disagrees with the
        # prior row's actual held snapshot and cannot make a rest window.
        rows=self.fresh_rows(row)
        for current in rows[1:]:
            current['application']['snapshot']=1
            current['application_step']['snapshot_before']=0
            current['application_step']['snapshot_after']=1
        self.assertIsNone(summarize(raw,rows)['rest_gate'])
    def test_compound_freshness_binds_actual_observation_snapshot(self):
        raw={'ok':True,'case':{'kind':'compound'}}
        rows=[]
        for i in range(300):
            receipt={'session':7,'bodies':[{'id':1,'sample':i+1,'session':7,'quiet_admitted':True}]}
            app={'accepted':True,'snapshot':i+1,'bodies':[{'index':0,'session':7,'sample':i+1,'age':0}]}
            rows.append({'row':i,'position':[0,0],'velocity':[0,0],'entry_com':0,'hard_clearance':True,
                         'application_step':{'version':1,'physics_call':i,'snapshot_before':i,'snapshot_after':i+1,'delivered_this_step':True},
                         'metrics':{'last_compound_observation':{'snapshot_serial':i+1,'rest_receipt':receipt,'application':app,'native_diagnostics':{}}}})
        self.assertTrue(summarize(raw,rows)['rest_gate'])
        rows[-1]['metrics']['last_compound_observation']['snapshot_serial']=299
        self.assertIsNone(summarize(raw,rows)['rest_gate'])
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
    def test_global_conservation_accounts_payload_cut_edits_and_water_quantity(self):
        before=[0]*64;before[2]=1000;before[3]=10;before[43]=600;before[0]=1048576-sum(before)
        final=before[:];final[2]-=7;final[3]=99;final[43]-=548;final[0]=1048576-sum(final[1:])
        edit_before=before[:];edit_after=before[:];edit_after[2]-=7;edit_after[0]+=7
        census=lambda counts,water=123:{'ok':True,'domain':[0,0,1024,1024],'tiles':4,'completed_ticks':1,'counts':counts,'water_mass':water,'scope':'global1024x1024 authoritative cells'}
        raw={'case':{'surroundings':'isolated_excavate'},'before':{'global_census':census(before)},'after':{'global_census':census(final)},
             'edits':[{'before':{'global_census':census(edit_before)},'after':{'global_census':census(edit_after)}}]}
        proof=compound_conservation(raw)
        self.assertIsNone(proof['conserved']);self.assertTrue(proof['observed_edit_adjusted_balance']);self.assertTrue(proof['water_quantity_exact'])
        final[2]-=1;final[0]+=1
        proof=compound_conservation(raw);self.assertIsNone(proof['conserved']);self.assertFalse(proof['observed_edit_adjusted_balance']);self.assertEqual(proof['count_mismatches'][0]['material'],2)
        final[2]+=1;final[0]-=1;raw['after']['global_census']['water_mass']=124
        self.assertFalse(compound_conservation(raw)['observed_edit_adjusted_balance'])
        raw['after']['global_census']['water_mass']=123.0
        self.assertEqual(compound_conservation(raw)['refusal'],'MALFORMED_COUNTS_OR_NONINTEGER_WATER_QUANTITY')
    def test_unedited_global_gate_requires_complete_domain_and_sand_balance(self):
        before=[0]*64;before[2]=1000;before[43]=600;before[0]=1048576-sum(before)
        final=before[:];final[43]-=528;final[0]+=528
        census=lambda c:{'ok':True,'domain':[0,0,1024,1024],'tiles':4,'completed_ticks':1,'counts':c,'water_mass':0,'scope':'global'}
        raw={'case':{'surroundings':'packed_sand'},'before':{'global_census':census(before)},'after':{'global_census':census(final)},'edits':[]}
        self.assertTrue(compound_conservation(raw)['conserved'])
        final[2]-=1;final[0]+=1
        self.assertFalse(compound_conservation(raw)['conserved'])
        final[2]+=1;final[0]-=1;raw['after']['global_census']['domain']=[0,0,160,128]
        self.assertEqual(compound_conservation(raw)['refusal'],'INCOMPLETE_GLOBAL_DOMAIN_OR_TILING')
    def test_regional_census_does_not_substitute_for_missing_global_gate(self):
        before=[0]*64;before[2]=1000;before[43]=600
        final=before[:];final[43]-=528
        raw={'case':{'surroundings':'packed_sand'},'before':{'diagnostic_snapshot':{'counts':before,'water_mass':0}},
             'after':{'diagnostic_snapshot':{'counts':final,'water_mass':0}},'edits':[]}
        self.assertTrue(compound_conservation(raw,False)['conserved'])
        self.assertIsNone(compound_conservation(raw)['conserved'])
if __name__=='__main__':unittest.main()
