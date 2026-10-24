import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import verify
import assembly_report
import timing
import verify_timing


class EvidenceContracts(unittest.TestCase):
    def test_empty_evidence_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(verify.verify(Path(d))['status'],'failed')

    def test_unsafe_paths_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            for p in ['../escape','C:/escape','/escape','a\\b','']:
                with self.assertRaises(ValueError): verify.checked(Path(d),p)

    def test_duplicate_json_rejected(self):
        with self.assertRaises(ValueError): json.loads('{"a":1,"a":2}',object_pairs_hook=verify.unique)

    def test_hash_and_inventory_not_optional(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); (p/'files.json').write_text('{}'); (p/'extra').write_text('x')
            self.assertIn('missing or extra',verify.verify(p)['errors'][0])
            (p/'files.json').write_text('{"extra":"bad"}')
            self.assertIn('hash mismatch',verify.verify(p)['errors'][0])

    def test_admission_held_in_each_registration(self):
        for p in Path(__file__).parent.glob('*registration*.json'):
            r=json.loads(p.read_text())
            if p.name=='wclear-admitted-registration.json':
                self.assertIs(r['formal_timing_admitted'],True)
                self.assertEqual(r['independent_review']['decision'],'admitted')
                self.assertIs(r['execution_authorized'],False)
            else:
                self.assertIs(r['formal_timing_admitted'],False)

    def test_instruction_accounting_excludes_labels_directives(self):
        s='\t.type get_a, @function\nget_a:\n\t.cfi_startproc\n\tmovq (%rdi), %rax\n\tret\n\t.size get_a, .-get_a\n'
        # Include zero-operand instructions as well as operand instructions.
        self.assertEqual(assembly_report.functions(s)['get_a'],['movq (%rdi), %rax','ret'])

    def test_arm_identity_and_compile_flags_fail_closed(self):
        self.assertEqual(verify.identity('memcpy-e16-x2'),('memcpy',16,2))
        with self.assertRaises(ValueError): verify.identity('memcpy-e7-x2')
        argv=['g++-13','-std=c++20','-O2','-DNDEBUG','-Wall','-Wextra','-Wpedantic','-pthread',
              '-DMAT003_STORAGE_KIND=3','-DMAT003_EXTRA_BYTES=2','-DMAT003_SPLIT=0',
              '-DMAT003_ARM_ID="C80-E16-memcpy"','-DMAT003_EPOCH_BITS=16','-DMAT003_TWIN_OBSERVERS=1',
              '-DMAT003_WORLD_SOURCE="/test/overlays/memcpy-e16-x2/native/src/world.cpp"','-I/test','test.cpp','-o','binary']
        verify.check_compile(argv,'memcpy-e16-x2',1)
        for changed in [argv[:2]+['-O3']+argv[3:], [v.replace('EPOCH_BITS=16','EPOCH_BITS=8') for v in argv],
                        [v.replace('OBSERVERS=1','OBSERVERS=0') for v in argv]]:
            with self.assertRaises(ValueError): verify.check_compile(changed,'memcpy-e16-x2',1)

    def test_timing_gate_rejects_before_authority_or_execution(self):
        registration=Path(__file__).parent/'wclear-registration-v2.json'
        with self.assertRaisesRegex(ValueError,'HELD: no independent'):
            timing.gates(registration,Path('nonexistent-owner-authority.json'))

    def test_exact_timing_schedule_is_bounded_and_interleaved(self):
        rows=timing.schedule()
        self.assertEqual(len(rows),672)
        self.assertEqual([r['role'] for r in rows[:6]],list('ABBAAB'))
        self.assertEqual(len({(r['epoch_bits'],r['side'],r['scene'],r['workers'],r['pair'],r['role']) for r in rows}),672)

    def test_timing_reduction_preserves_extreme_and_negative_excess(self):
        # Synthetic reader contract only, never a World timing observation.
        s=verify_timing.summary([-9,1,2,3,4,5,1000000])
        self.assertEqual((s['median'],s['minimum'],s['p95'],s['p99'],s['maximum']),(3,-9,1000000,1000000,1000000))
        self.assertEqual(s['mad'],2)


if __name__=='__main__': unittest.main()
