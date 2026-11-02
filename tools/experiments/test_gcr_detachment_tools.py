"""Synthetic regressions for the qualification guard and measurement claims."""
import json
from pathlib import Path
import tempfile
import unittest

import analyze_gcr_detachment as analyze
import run_gcr_detachment as run


class QualificationTests(unittest.TestCase):
    def test_native_project_path_accepts_canonical_and_local_manifests(self):
        project=Path('isolated-project')
        for artifact in ['godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll',
                         'build/godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll']:
            self.assertEqual(run.native_project_path(project,artifact),project/'addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll')

    def test_population_is_bounded_and_repeat_is_separate(self):
        protocol=json.loads(run.PROTOCOL.read_text(encoding='utf-8'))
        population=[row for platform in protocol['platforms'] for row in run.schedule(protocol,platform)]
        self.assertEqual(len(population),56)
        self.assertEqual(sum(row['repeat']==0 for row in population),48)
        self.assertEqual(sum(row['repeat']==1 for row in population),8)
        self.assertTrue(all(row['arm']=='R2' and row['workers']==1 for row in population if row['repeat']))
        self.assertEqual(len({tuple(sorted(row.items())) for row in population}),56)
        self.assertTrue((run.ROOT/protocol['capture']['script']).is_file())
        self.assertFalse((run.ROOT/'godot/tests/test_gcr_detachment_capture.gd').exists())

    def test_mechanical_receipt_all_identity_and_gates_required(self):
        protocol=json.loads(run.PROTOCOL.read_text(encoding='utf-8'))
        identity={key:key+'-identity' for key in ['source','protocol_sha256','native_sha256','input_identity']}
        receipt={**identity,'ok':True,'gates':dict.fromkeys(protocol['mechanical_prerequisites'],True)}
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'mechanical.json'
            def write(value):
                path.write_text(json.dumps(value),encoding='utf-8')
            write(receipt)
            self.assertEqual(run.validate_mechanical(path,identity,protocol),run.digest(path))
            for key in identity:
                broken={**receipt,key:'stale'};write(broken)
                with self.assertRaisesRegex(RuntimeError,'identity mismatch'):
                    run.validate_mechanical(path,identity,protocol)
            write({**receipt,'gates':{**receipt['gates'],'independent_full_node_oracle':False}})
            with self.assertRaisesRegex(RuntimeError,'Missing mechanical'):
                run.validate_mechanical(path,identity,protocol)
            self.assertTrue(path.exists(), 'negative receipt retained')
            with self.assertRaisesRegex(RuntimeError,'requires'):
                run.validate_mechanical(None,identity,protocol)

    def test_held_raw_wrench_does_not_become_applied(self):
        row={'metrics':{'last_compound_observation':{'snapshot_serial':12,'computed_result':[1,3,4,0,0,0,0,0,2,7,0,0,2,73],
                'application':{'snapshot':12,'accepted':False,'refusal':'held','bodies':[]}}}}
        value=analyze.application_ledger([row,row])
        self.assertEqual(value['actually_applied_impulse'],[0.,0.])
        self.assertEqual(value['actually_applied_angular_impulse'],0.)
        self.assertEqual(value['receipts'],1)
        self.assertEqual(value['refused'],1)

    def test_actual_scaled_translated_wrench_and_dedup(self):
        row={'metrics':{'last_compound_observation':{'snapshot_serial':3,'application':{'snapshot':3,'accepted':True,
             'bodies':[{'impulse':[2.4,3.2],'angular_impulse':5.1,'age':1,'contact_displacement':.25}]}}}}
        value=analyze.application_ledger([row,row])
        self.assertEqual(value['actually_applied_impulse'],[2.4,3.2])
        self.assertEqual(value['actually_applied_angular_impulse'],5.1)
        self.assertEqual(value['accepted'],1)

    def test_missing_overlap_and_delivery_are_not_false_zero(self):
        raw={'case':{},'rows':[{'position':[1,2],'pre_overlap':None,'post_overlap':None}], 'source_receipt':{'center':[1,1]}}
        value=analyze.summary(raw)
        self.assertIsNone(value['post_overlap_max'])
        self.assertIsNone(value['application']['actually_applied_impulse'])
        self.assertIsNone(analyze.regression(None,None,.1,1.))
        self.assertIsNone(value['cutoff_derivative'])
        self.assertIsNone(value['components']['timing']['result_generation_usec']['p95'])

    def test_legacy_uses_explicit_applied_reducer_values(self):
        app={'accepted':True,'impulse':[9,9],'actual_impulse':[.1,.2],'actual_angular_impulse':.3}
        self.assertEqual(analyze.actual_application(app),([.1,.2],.3))
        self.assertEqual(analyze.actual_application({'accepted':True,'bodies':[]}),(None,None))

    def test_failed_partial_cannot_pass_gate_with_better_entry(self):
        reference={'capture':{'status':'captured'},'summary':{'capture_ok':True,'reference_entry_com_cells':10.,'post_overlap_max':4.}}
        partial={'capture':{'status':'failed'},'summary':{'capture_ok':True,'reference_entry_com_cells':0.,'post_overlap_max':0.}}
        gates=analyze.pair_gates(reference,partial)
        self.assertIsNone(gates['entry_gate']);self.assertIsNone(gates['overlap_gate'])
        self.assertEqual(partial['summary']['reference_entry_com_cells'],0.,'partial diagnostic remains available')
        partial['capture']['status']='captured';partial['summary']['capture_ok']=False
        self.assertIsNone(analyze.pair_gates(reference,partial)['entry_gate'])
        partial['summary']['capture_ok']=True
        self.assertTrue(analyze.pair_gates(reference,partial)['entry_gate'])

    def test_observed_overlap_dedups_and_does_not_fill_primary_gap(self):
        def row(serial,measured,pre=None,post=None):
            return {'metrics':{'last_compound_observation':{'snapshot_serial':serial,'native_diagnostics':
                {'overlap_measured':measured,'cellular_overlap_pre':pre,'cellular_overlap_post':post,'overlap_scope':'cell centers in union'}}}}
        first=row(1,True,5,2)
        rows=[first,first,row(2,False,999,999),row(3,True,7,0)]
        value=analyze.native_observed_ledger(rows)
        self.assertEqual(value['observed_snapshot_count'],3)
        self.assertEqual(value['overlap']['measured_snapshots'],2)
        self.assertEqual(value['overlap']['coverage'],2/3)
        self.assertEqual(value['overlap']['observed_pre_peak'],7)
        self.assertEqual(value['overlap']['observed_post_peak'],2)
        self.assertIsNone(analyze.summary({'case':{},'rows':rows})['post_overlap_max'])
        unsupported=analyze.native_observed_ledger([{'metrics':{'last_compound_observation':{'snapshot_serial':1}}}])
        self.assertIsNone(unsupported['overlap']['coverage'])
        self.assertIsNone(unsupported['overlap']['observed_post_peak'])

    def test_confirmed_cut_material_balance_and_unknown_effect(self):
        before=[0]*44;after=[0]*44
        before[43]=548;after[43]=20;before[1]=after[1]=100;before[2]=after[2]=10
        members=[0,0,43,0,0,200]*520
        raw={'before':{'diagnostic_snapshot':{'counts':before,'water_mass':255}},
             'after':{'diagnostic_snapshot':{'counts':after,'water_mass':255},'aggregate_owned':520,'native_source_members':0,'members':members},
             'source_receipt':{'members':members},'external_edits_complete':True,'cut_effect':{'known':True},
             'external_edits':[{'removed_material':43,'removed_cells':8}]}
        value=analyze.conservation(raw)
        self.assertTrue(value['brick_balance']);self.assertTrue(value['wall_unchanged']);self.assertTrue(value['all_registered_observed_exact'])
        after[43]=21
        self.assertFalse(analyze.conservation(raw)['brick_balance'])
        raw['external_edits_complete']=False
        self.assertIsNone(analyze.conservation(raw)['brick_balance'])
        raw['source_receipt']['members']=[];raw['after']['members']=[]
        self.assertFalse(analyze.conservation(raw)['member_tuples'],'equal empty payloads do not prove520 tuples retained')

    def test_refusal_and_correction_zeroing_are_snapshot_ledgers(self):
        accepted={'metrics':{'last_compound_observation':{'snapshot_serial':1,'application':{'snapshot':1,'accepted':True,'bodies':[
            {'impulse':[0.,0.],'angular_impulse':0.,'correction':[0.,-.5],'correction_applied':True,
             'velocity_before_correction':[0.,3.],'velocity_after_zeroing':[0.,0.]}]}}}}
        refused={'metrics':{'last_compound_observation':{'snapshot_serial':2,'computed_result':[],
            'application':{'snapshot':2,'accepted':False,'refusal':'layout','bodies':[]}}}}
        value=analyze.application_ledger([accepted,accepted,refused,refused])
        self.assertEqual(value['correction_count'],1);self.assertEqual(value['zeroing_count'],1)
        self.assertEqual(value['refusal_reasons'],{'layout':1});self.assertEqual(value['empty_result_refusals'],1)
        self.assertEqual(value['actually_applied_impulse'],[0.,0.])

    def test_native_energy_work_requires_actual_computed_copy(self):
        def row(serial,values):
            return {'metrics':{'last_compound_observation':{'snapshot_serial':serial,'native_diagnostics':values}}}
        missing=row(1,{'computed':False,'nodes':999,'energy_before':0,'energy_after':999})
        valid=row(2,{'computed':True,'nodes':4,'updates':32,'energy_before':10,'energy_after':9,
                     'normal_accepted':3,'event_budget_cost':4,'passivity_rejected':True})
        value=analyze.native_observed_ledger([missing,valid,valid])
        self.assertEqual(value['computed_snapshots'],1)
        self.assertEqual(value['budget_work_energy']['nodes']['max'],4)
        self.assertEqual(value['passive_energy_delta']['max'],-1)
        self.assertEqual(value['normal_accepted_plus_event_cost']['max'],7)
        self.assertEqual(value['passivity_rejected'],1)
        self.assertIsNone(analyze.native_observed_ledger([missing])['passivity_rejected'])


if __name__=='__main__':
    unittest.main()
