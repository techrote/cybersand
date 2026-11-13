"""Strict optional TRAIN-only coral m0 witness overlay regressions."""
import json
import os
from pathlib import Path
import tempfile
import unittest

import failure_witness_overlay as target


class WitnessOverlayTests(unittest.TestCase):
    def test_modifier_requires_original_trace_identity(self):
        row = {'id': 'coral-v4-m0-s17-p1', 'native_case_id': 'coral-v4-m0-s17'}
        self.assertEqual(target.modifier(row), 0)
        for altered in ({**row, 'id': 'coral-v4-m8-s17-p1'},
                        {**row, 'native_case_id': 'coral-v7-m0-s17'},
                        {**row, 'id': 'coral-v4-m0-s17-p1 trailing'}):
            with self.assertRaisesRegex(ValueError, 'noncanonical'):
                target.modifier(altered)

    def test_composition_is_program_not_nominal_variant(self):
        one = {'completion': '{"theme":"coral","layers":[{"motif":"fan"}]}' }
        two = {'completion': '{"theme":"coral","layers":[{"motif":"fan"},{"motif":"branch"}]}' }
        self.assertFalse(target.composed(one))
        self.assertTrue(target.composed(two))

    def test_missing_archive_rows_refused(self):
        with self.assertRaisesRegex(ValueError, 'cardinality'):
            target.overlay([], [])
        source = [{'id': f'fake-{i}'} for i in range(1152)]
        prefix = [{'id': f'fake-{i}'} for i in range(400)]
        with self.assertRaisesRegex(ValueError, 'missing original'):
            target.overlay(prefix, source)

    def test_duplicate_original_witness_refused(self):
        source = [{'id': f'fake-{i}'} for i in range(1150)]
        source += [{'id': target.OLD}, {'id': target.NEW}]
        prefix = [{'id': f'fake-{i}'} for i in range(398)]
        prefix += [{'id': target.OLD}, {'id': target.OLD}]
        with self.assertRaisesRegex(ValueError, 'witness positions'):
            target.overlay(prefix, source)


class ArchivedWitnessTests(unittest.TestCase):
    def test_native_admitted_v4_exact_manifest(self):
        here = Path(__file__).parent
        corpus = Path(os.environ.get('WB_ART_SLM_CORPUS_DIR', str(here)))
        required = ('train.jsonl', 'dev.jsonl', 'final.jsonl',
                    'native_cases.json', 'manifest.json', 'admission.json')
        if not all((corpus / name).is_file() for name in required):
            self.skipTest('original native-executed corpus not available')
        with tempfile.TemporaryDirectory() as tmp:
            result = target.build(corpus, Path(tmp))
            pinned = json.loads((here / 'coral_m0_composed_witness_v4.json').read_text())
            self.assertEqual(result, pinned)
            self.assertEqual(target.ids_hash([{'id': target.OLD}]),
                             target.sha((target.OLD + '\n').encode()))
            indices = json.loads((Path(tmp) / 'v4_source_indices.json').read_text())
            self.assertEqual(len(indices), 400)
            self.assertEqual(target.index_hash(indices), pinned['v4_original_source_indices_sha256'])
            self.assertEqual(pinned['coral_m0_composed_after'], 1)
            self.assertEqual(pinned['coral_m6_composed_preserved'], 2)


if __name__ == '__main__':
    unittest.main()