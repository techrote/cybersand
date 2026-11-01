"""Registration/order/identity/reduction regressions without efficacy acquisition."""
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock
import hashlib

from run_gcr_admission import PROTOCOL, schedule, validate_mechanical_receipt, validate_registration
from analyze_gcr_admission import admission_summary, reduce_reports
import run_gcr_qualification as legacy
import run_gcr_admission as admission_runner


class AdmissionTests(unittest.TestCase):
    def setUp(self):self.protocol=json.loads(PROTOCOL.read_text(encoding='utf-8'))

    def test_exact_registered_population_and_orders(self):
        self.assertEqual([len(schedule(self.protocol,p)) for p in ['primary','async','controls','replay','timing']],[156,18,9,9,45])
        for case in self.protocol['synchronous']['case_ids']:
            arms={a for c,a,_,_ in schedule(self.protocol,'primary') if c==case}
            self.assertEqual(arms,{'Y1','GCR-A1','GCR'} if case in self.protocol['synchronous']['additional_R2_case_ids'] else {'Y1','GCR-A1'})
        t=schedule(self.protocol,'timing')
        for repeat,order in enumerate(self.protocol['performance']['repeat_arm_orders']):
            self.assertEqual([a for c,a,r,_ in t if c=='sand-vertical' and r==repeat],order)

    def test_frozen_registration_integrity(self):validate_registration(self.protocol)

    def test_unicode_function_and_catalogue_hashes_use_utf8(self):
        # Simulate non-ASCII locked source independently of the host locale.
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);oldpath='docs/protocol.json';canonical=json.dumps({'cases':[],'controls':[],'async_cases':[],'label':'\u03bc\u2192'},ensure_ascii=False).encode('utf-8')
            (root/'docs').mkdir();(root/oldpath).write_bytes(canonical)
            catalogue='const label = "\u03bc \u2192 \u96ea"\n';(root/'catalogue.gd').write_text(catalogue,encoding='utf-8')
            relative='godot/native_extension/cyber_native_cell_world.cpp';(root/relative).parent.mkdir(parents=True)
            source='double World::locked() { // \u03bb\u2192\u03bc\nreturn 1;\n}'
            (root/relative).write_text(source,encoding='utf-8')
            protocol={'inherited_scenarios':{'path':oldpath,'canonical_sha256':hashlib.sha256(canonical).hexdigest()},
                      'cases':[],'controls':[],'async_cases':[],
                      'frozen_law_files':{'catalogue.gd':hashlib.sha256(catalogue.encode('utf-8')).hexdigest()},
                      'frozen_adapter_functions':{'World::locked(':hashlib.sha256(source[source.index('World::locked('):].encode('utf-8')).hexdigest()}}
            with mock.patch.object(admission_runner,'ROOT',root),mock.patch.object(legacy,'git',return_value=canonical):
                validate_registration(protocol)

    def test_legacy_authentication_does_not_silently_admit_new_registration(self):
        with self.assertRaisesRegex(RuntimeError,'Expected the frozen 66-case GCR-001 registration'):
            legacy.authenticate(SimpleNamespace(),protocol_path=PROTOCOL)

    def test_mechanical_receipt_cannot_be_missing_stale_or_partial(self):
        identity=dict(source='s',protocol_sha256='p',native_sha256='n',input_identity='i')
        with self.assertRaises(RuntimeError):validate_mechanical_receipt(None,identity)
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'receipt.json';value=dict(identity,ok=True,gates=dict(native_query=True,independent_oracle=True,adapter=False));path.write_text(json.dumps(value),encoding='utf-8')
            with self.assertRaises(RuntimeError):validate_mechanical_receipt(path,identity)
            value['gates']['adapter']=True;path.write_text(json.dumps(value),encoding='utf-8');self.assertEqual(len(validate_mechanical_receipt(path,identity)),64)
            value['source']='stale';path.write_text(json.dumps(value),encoding='utf-8')
            with self.assertRaises(RuntimeError):validate_mechanical_receipt(path,identity)
            for key in identity:
                refused=dict(identity,ok=True,gates=dict(native_query=True,independent_oracle=True,adapter=True));refused[key]='wrong'
                path.write_text(json.dumps(refused),encoding='utf-8');before=path.read_bytes()
                with self.assertRaises(RuntimeError):validate_mechanical_receipt(path,identity)
                self.assertEqual(path.read_bytes(),before,'refusal must retain original evidence bytes')
            passing=dict(identity,ok=True,gates=dict(native_query=True,independent_oracle=True,adapter=True))
            path.write_text(json.dumps(passing),encoding='utf-8');before=path.read_bytes()
            self.assertEqual(validate_mechanical_receipt(path,identity),hashlib.sha256(before).hexdigest())
            self.assertEqual(path.read_bytes(),before,'validation must not restamp passing evidence')

    def test_missing_admission_is_unknown_and_bounds_are_actual(self):
        self.assertIsNone(admission_summary({'mode':'synchronous','rows':[{}]}))
        r={'mode':'synchronous','rows':[{'admission':{'source_candidates':1,'mask_checks':32,'path_checks':7,'geometry_mask_checks':24,'shared_witness_calls':1,'admitted':1}}]}
        result=admission_summary(r);self.assertFalse(result['all_observed_probe_bounds_satisfied']);self.assertEqual(result['bound_violation_boundaries']['mask_checks'],1)

    def test_actual_A1_label_is_required(self):
        report={'candidate':'GCR-A1','registration':'GCR-ADMISSION-001-2026-11-01','granular_identity':{'admission_variant':'R2'}}
        with self.assertRaises(RuntimeError):reduce_reports([(report,0,'hash')])


if __name__=='__main__':unittest.main()
