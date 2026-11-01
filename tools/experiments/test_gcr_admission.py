"""Registration/order/identity/reduction regressions without efficacy acquisition."""
import json
from pathlib import Path
import tempfile
import unittest

from run_gcr_admission import PROTOCOL, schedule, validate_mechanical_receipt, validate_registration
from analyze_gcr_admission import admission_summary, reduce_reports


class AdmissionTests(unittest.TestCase):
    def setUp(self):self.protocol=json.loads(PROTOCOL.read_text())

    def test_exact_registered_population_and_orders(self):
        self.assertEqual([len(schedule(self.protocol,p)) for p in ['primary','async','controls','replay','timing']],[156,18,9,9,45])
        for case in self.protocol['synchronous']['case_ids']:
            arms={a for c,a,_,_ in schedule(self.protocol,'primary') if c==case}
            self.assertEqual(arms,{'Y1','GCR-A1','GCR'} if case in self.protocol['synchronous']['additional_R2_case_ids'] else {'Y1','GCR-A1'})
        t=schedule(self.protocol,'timing')
        for repeat,order in enumerate(self.protocol['performance']['repeat_arm_orders']):
            self.assertEqual([a for c,a,r,_ in t if c=='sand-vertical' and r==repeat],order)

    def test_frozen_registration_integrity(self):validate_registration(self.protocol)

    def test_mechanical_receipt_cannot_be_missing_stale_or_partial(self):
        identity=dict(source='s',protocol_sha256='p',native_sha256='n',input_identity='i')
        with self.assertRaises(RuntimeError):validate_mechanical_receipt(None,identity)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'receipt.json';value=dict(identity,ok=True,gates=dict(native_query=True,independent_oracle=True,adapter=False));path.write_text(json.dumps(value))
            with self.assertRaises(RuntimeError):validate_mechanical_receipt(path,identity)
            value['gates']['adapter']=True;path.write_text(json.dumps(value));self.assertEqual(len(validate_mechanical_receipt(path,identity)),64)
            value['source']='stale';path.write_text(json.dumps(value))
            with self.assertRaises(RuntimeError):validate_mechanical_receipt(path,identity)

    def test_missing_admission_is_unknown_and_bounds_are_actual(self):
        self.assertIsNone(admission_summary({'mode':'synchronous','rows':[{}]}))
        r={'mode':'synchronous','rows':[{'admission':{'source_candidates':1,'mask_checks':32,'path_checks':7,'geometry_mask_checks':24,'shared_witness_calls':1,'admitted':1}}]}
        result=admission_summary(r);self.assertFalse(result['all_observed_probe_bounds_satisfied']);self.assertEqual(result['bound_violation_boundaries']['mask_checks'],1)

    def test_actual_A1_label_is_required(self):
        report={'candidate':'GCR-A1','registration':'GCR-ADMISSION-001-2026-11-01','granular_identity':{'admission_variant':'R2'}}
        with self.assertRaises(RuntimeError):reduce_reports([(report,0,'hash')])


if __name__=='__main__':unittest.main()
