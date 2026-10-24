"""Failure contracts for held S2P execution, not timing tests."""
import json,tempfile,unittest
from pathlib import Path
import measure
class Contracts(unittest.TestCase):
 def test_frozen_matrix(self):
  r=json.loads(Path(__file__).with_name('registration.json').read_text());rows=measure.schedule(r)
  self.assertEqual(len(rows),56);self.assertEqual(len({b['id'] for b in r['arms']}),5)
  self.assertEqual([x['role'] for x in rows[:4]],list('ABBA'))
  self.assertFalse(r['formal_timing_admitted']);self.assertFalse(r['execution_authorized'])
 def test_preregistration_never_grants_execution(self):
  with tempfile.TemporaryDirectory() as d:
   a=Path(d)/'authority.json';a.write_text('{}')
   with self.assertRaisesRegex(ValueError,'HELD'):measure.gates(Path(__file__).with_name('registration.json'),a)
 def test_admission_without_owner_receipt_stays_held(self):
  with tempfile.TemporaryDirectory() as d:
   a=Path(d)/'admission.json';o=Path(d)/'authority.json'
   a.write_text(json.dumps(dict(status='admitted-paired-timing',formal_timing_admitted=True,author='author',independent_review=dict(decision='admitted',reviewer='independent'))));o.write_text('{}')
   with self.assertRaisesRegex(ValueError,'owner'):measure.gates(a,o)
if __name__=='__main__':unittest.main()
