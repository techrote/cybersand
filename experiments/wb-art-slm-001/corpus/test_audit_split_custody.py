"""Corpus audit regressions; original archived corpus is never modified."""
import json
import os
from pathlib import Path
import unittest
from zipfile import ZipFile

from audit_split_custody import (ARCHIVE_SHA256, audit_archive, group_for,
                                 normalized_prompt, signature,
                                 validate_pairs_and_leakage)

ARCHIVE = Path(os.environ.get('WB_ART_SLM_CORPUS_ARCHIVE',
           '/nonexistent/wb_art_slm_001_executed_corpus.zip'))


class SplitCustodyTests(unittest.TestCase):
    def test_post_modifier_signature_changes_with_motif_layout_not_seed_or_numerics(self):
        p = {'version': 1, 'theme': 'coral', 'layers': [
            {'motif': 'fan', 'layout': 'border', 'angle': 0, 'density': .5}]}
        first = group_for(p)
        p['layers'][0]['density'] = .9
        self.assertEqual(first, group_for(p))
        p['layers'][0]['layout'] = 'split'
        self.assertNotEqual(first, group_for(p))
        p['layers'][0]['motif'] = 'network'
        self.assertNotEqual(first, group_for(p))
        self.assertIn('"structure"', signature(p))

    def test_unicode_nfkc_casefold_prompt_leak(self):
        self.assertEqual(normalized_prompt('  ＣＯＲＡＬ   \n  center  '), 'coral center')

    @unittest.skipUnless(ARCHIVE.is_file(), 'exact owner corpus archive not mounted')
    def test_exact_archived_train_dev_native_receipts_and_final_seal(self):
        report = audit_archive(ARCHIVE)
        self.assertEqual(report['archive_sha256'], ARCHIVE_SHA256)
        self.assertEqual(report['train_records'], 1152)
        self.assertEqual(report['dev_records'], 192)
        self.assertEqual(report['trace_pairs_verified'], 672)
        self.assertEqual(report['program_and_prompt_leakage_train_dev'], 0)
        self.assertFalse(report['raw_global_receipt_packet_replayed'])

    @unittest.skipUnless(ARCHIVE.is_file(), 'exact owner corpus archive not mounted')
    def test_adversarial_rows_fail_closed(self):
        with ZipFile(ARCHIVE) as z:
            get = lambda name: json.loads(z.read('corpus/' + name))
            admission = get('admission.json')
            manifest = get('manifest.json')
            groups = {g['group_id']: g for g in manifest['groups']}
            cases = {c['id']: c for c in get('native_cases.json')['cases']}
            rows = {s: [json.loads(x) for x in z.read('corpus/' + s + '.jsonl').splitlines()]
                    for s in ('train', 'dev')}
        self.assertEqual(validate_pairs_and_leakage(rows, groups, cases, admission['runtime'])['trace_pairs_verified'], 672)
        tests = [
            ('recomputed group', 'train', 0, 'group_id', 'roots:0000000000000000'),
            ('compiled program', 'train', 0, 'completion', '{"version":1,"theme":"coral","layers":[]}'),
            ('operation binding', 'dev', 0, 'operations_sha256', '0' * 64),
            ('native receipt', 'dev', 0, 'native_qualified', False),
            ('exact prompt leakage', 'dev', 0, 'prompt', rows['train'][0]['prompt']),
            ('trace pairing', 'train', 1, 'id', rows['train'][0]['id']),
        ]
        for label, split, index, key, changed in tests:
            with self.subTest(label=label):
                mutated = {s: list(v) for s, v in rows.items()}
                mutated[split][index] = dict(mutated[split][index], **{key: changed})
                with self.assertRaises(ValueError):
                    validate_pairs_and_leakage(mutated, groups, cases, admission['runtime'])


if __name__ == '__main__':
    unittest.main()
