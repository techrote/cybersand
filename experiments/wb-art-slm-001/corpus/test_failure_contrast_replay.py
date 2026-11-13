#!/usr/bin/env python3
"""Fail-closed v5 corpus-only controls, with optional actual sealed archive test."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_failure_contrast_replay as replay

ARCHIVE = os.environ.get('WB_ART_SLM_CORPUS_ARCHIVE')


class FailureContrastTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if ARCHIVE:
            cls.rows, _ = replay.read_archive(Path(ARCHIVE))

    def test_missing_or_changed_native_receipt_is_refused(self):
        sample = {'id': 'veins-v0-m0-s17-p0', 'theme': 'veins',
                  'native_case_id': 'veins-v0-m0-s17', 'split': 'train',
                  'native_qualified': True, 'seed': 17, 'material': 58,
                  'width': 96, 'height': 96, 'visual_review': 'case-inspected',
                  'native_runtime': {'source_commit': replay.SOURCE},
                  'completion': json.dumps({'theme': 'veins', 'version': 1,
                                            'layers': [{'motif': 'network'}]}),
                  'operations_sha256': 'correct',
                  'native_receipt': {'id': 'veins-v0-m0-s17', 'success': True,
                                     'operations_sha256': 'correct', 'changed_cells': 1,
                                     'outside_focus_violations': 0,
                                     'unexpected_material_cells': 0}}
        replay.verify_row(sample)
        for change in ('native_qualified', 'theme', 'material'):
            bad = copy.deepcopy(sample)
            bad[change] = False if change == 'native_qualified' else 'ruins' if change == 'theme' else 59
            with self.assertRaises(ValueError):
                replay.verify_row(bad)
        bad = copy.deepcopy(sample)
        bad['native_receipt']['operations_sha256'] = 'forged'
        with self.assertRaises(ValueError):
            replay.verify_row(bad)
        bad = copy.deepcopy(sample)
        bad['completion'] = json.dumps({'theme': 'veins', 'version': 1,
                                        'layers': [{'motif': 'orthogonal'}]})
        with self.assertRaises(ValueError):
            replay.verify_row(bad)

    def test_index_digest_cannot_hide_reordering(self):
        self.assertNotEqual(replay.index_digest([1, 2, 1]), replay.index_digest([1, 1, 2]))
        self.assertNotEqual(replay.index_digest([0]), replay.index_digest([00, 0]))

    @unittest.skipUnless(ARCHIVE, 'original 2,311,486-byte owner corpus archive not mounted')
    def test_exact_archived_native_admitted_failure_contrasts(self):
        out, pairs = replay.build_rows(self.rows)
        self.assertEqual(400, len(out))
        self.assertEqual(8, len(pairs['matched_positive_pairs']))
        self.assertEqual(4, len(pairs['coral_composed']))
        for a, b in pairs['matched_positive_pairs']:
            ra, rb = next(r for r in out if r['id'] == a), next(r for r in out if r['id'] == b)
            self.assertEqual(ra['seed'], rb['seed'])
            self.assertNotEqual(ra['operations_sha256'], rb['operations_sha256'])
        self.assertEqual(200, sum(r['id'].endswith('-p0') for r in out))
        self.assertEqual(72, len({r['group_id'] for r in out}))

    @unittest.skipUnless(ARCHIVE, 'original 2,311,486-byte owner corpus archive not mounted')
    def test_immutable_source_index_manifest(self):
        manifest = replay.build(Path(ARCHIVE))
        target = Path(__file__).with_name('failure_contrast_replay_v5.json')
        self.assertEqual(manifest, json.loads(target.read_text()))
        self.assertEqual(manifest['source_indices_sha256'],
                         replay.index_digest(manifest['source_indices']))
        tampered = copy.deepcopy(manifest)
        tampered['source_indices'][16] = tampered['source_indices'][15]
        self.assertNotEqual(replay.index_digest(tampered['source_indices']),
                            manifest['source_indices_sha256'])


if __name__ == '__main__':
    unittest.main()
