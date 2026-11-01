"""Synthetic regressions for the qualification guard and measurement claims."""
import json
from pathlib import Path
import tempfile
import unittest

import analyze_gcr_detachment as analyze
import run_gcr_detachment as run


class QualificationTests(unittest.TestCase):
    def test_population_is_bounded_and_repeat_is_separate(self):
        protocol=json.loads(run.PROTOCOL.read_text(encoding='utf-8'))
        population=[row for platform in protocol['platforms'] for row in run.schedule(protocol,platform)]
        self.assertEqual(len(population),56)
        self.assertEqual(sum(row['repeat']==0 for row in population),48)
        self.assertEqual(sum(row['repeat']==1 for row in population),8)
        self.assertTrue(all(row['arm']=='R2' and row['workers']==1 for row in population if row['repeat']))
        self.assertEqual(len({tuple(sorted(row.items())) for row in population}),56)

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


if __name__=='__main__':
    unittest.main()
