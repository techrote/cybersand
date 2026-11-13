"""Corpus-owned tests of theme/form balance and replay source custody."""
from collections import Counter
import json
import os
from pathlib import Path
import tempfile
import unittest

import build_curriculum as baseline
import build_balanced_replay as candidate


def synthetic_traces():
    traces = {}
    for theme in baseline.THEMES:
        for variant in range(6):
            for modifier in range(8):
                key = f'{theme}-v{variant}-m{modifier}-s{17+modifier}'
                program = {'theme': theme, 'layers': [{'motif': 'network', 'layout': 'center'}]}
                traces[key] = {
                    form: {
                        'id': key + '-' + form, 'native_case_id': key,
                        'group_id': f'{theme}:v{variant}', 'theme': theme,
                        'prompt': theme if variant == 0 and modifier == 0 and form == 'p0' else 'other',
                        'completion': json.dumps(program)
                    } for form in ('p0', 'p1')
                }
    return traces


class BalanceTests(unittest.TestCase):
    def setUp(self):
        self.traces = synthetic_traces()

    def test_old_theme_phrase_coupling_and_new_balance(self):
        old = baseline.order_rows(self.traces)
        self.assertEqual(Counter(r['id'][-2:] for r in old[:400]), {'p0': 200, 'p1': 200})
        self.assertEqual(Counter(r['id'][-2:] for r in old[:400] if r['theme'] == 'coral'),
                         {'p0': 33, 'p1': 1})
        self.assertEqual(Counter(r['id'][-2:] for r in old[:400] if r['theme'] == 'veins'),
                         {'p1': 33, 'p0': 1})
        balanced = candidate.balanced_order(self.traces)
        self.assertEqual(len({r['id'] for r in balanced}), 1152)
        self.assertEqual(len({r['native_case_id'] for r in balanced[:576]}), 576)
        self.assertEqual(Counter(r['id'][-2:] for r in balanced[:400]), {'p0': 200, 'p1': 200})
        for theme in baseline.THEMES:
            counts = Counter(r['id'][-2:] for r in balanced[:400] if r['theme'] == theme)
            self.assertLessEqual(abs(counts['p0'] - counts['p1']), 1)
        self.assertEqual([r['id'] for r in balanced],
                         [r['id'] for r in candidate.balanced_order(self.traces)])

    def test_replay_keeps_themes_groups_and_no_new_source_rows(self):
        balanced = candidate.balanced_order(self.traces)
        prefix, changes = candidate.replay_prefix(balanced)
        self.assertEqual(len(prefix), 400)
        self.assertEqual(len(changes), 24)
        self.assertEqual(len(set(r['native_case_id'] for r in prefix)), 376)
        self.assertEqual(len(set(r['group_id'] for r in prefix)), 72)
        self.assertEqual(Counter(r['id'][-2:] for r in prefix), {'p0': 200, 'p1': 200})
        self.assertEqual(Counter(r['theme'] for r in prefix if r['prompt'] == r['theme']),
                         {theme: 3 for theme in baseline.THEMES})
        self.assertTrue(set(r['id'] for r in prefix) <= set(r['id'] for r in balanced))
        self.assertEqual(Counter(r['theme'] for r in prefix),
                         Counter(r['theme'] for r in balanced[:400]))

    def test_invalid_input_refused(self):
        order = candidate.balanced_order(self.traces)
        with self.assertRaisesRegex(ValueError, 'exact 1152-row'):
            candidate.replay_prefix(order[:399])
        bad = [dict(x) for x in order]
        bad[0] = dict(bad[0], prompt='not a literal')
        with self.assertRaisesRegex(ValueError, 'first twelve'):
            candidate.replay_prefix(bad)


class ArchivedEvidenceTests(unittest.TestCase):
    def test_exact_custody_and_golden_manifest(self):
        here = Path(__file__).parent
        folder = Path(os.environ.get('WB_ART_SLM_CORPUS_DIR', str(here)))
        required = ('train.jsonl', 'dev.jsonl', 'final.jsonl',
                    'native_cases.json', 'manifest.json', 'admission.json')
        if not all((folder / name).is_file() for name in required):
            self.skipTest('verified executed corpus archive not available')
        with tempfile.TemporaryDirectory() as out:
            result = candidate.build(folder, Path(out))
            golden = json.loads((here / 'curriculum_theme_phrase_replay_v2.json').read_text())
            self.assertEqual(result, golden)
            self.assertEqual(baseline.digest((Path(out) / 'balanced_train.jsonl').read_bytes()),
                             golden['balanced_jsonl_sha256'])
            self.assertEqual(len(json.loads((Path(out) / 'replay_first400_indices.json').read_text())), 400)


if __name__ == '__main__':
    unittest.main()
