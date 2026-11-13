"""Modifier-coverage and immutable archive replay checks (TRAIN only)."""
from collections import Counter
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_curriculum as base
import build_balanced_replay as v2
import build_modifier_replay as candidate

HERE = Path(__file__).parent


def synthetic_traces():
    traces = {}
    for theme in base.THEMES:
        for variant in range(6):
            for m in range(8):
                native_id = f'{theme}-v{variant}-m{m}-s{17 + m * 37}'
                traces[native_id] = {
                    phrase: {
                        'id': f'{native_id}-{phrase}',
                        'native_case_id': native_id,
                        'group_id': f'{theme}:v{variant}',
                        'theme': theme,
                        'prompt': theme if variant == 0 and m == 0 and phrase == 'p0' else 'other',
                        'completion': '{"theme":"' + theme + '","layers":[{"motif":"branch","layout":"center"}]}'
                    } for phrase in ('p0', 'p1')
                }
    return traces


class ModifierReplayTests(unittest.TestCase):
    def setUp(self):
        self.traces = synthetic_traces()
        source = v2.balanced_order(self.traces)
        self.source_hash = base.digest(('\n'.join(r['id'] for r in source) + '\n').encode())

    def order(self):
        with patch.object(candidate, 'V2_ORDER_SHA256', self.source_hash):
            return candidate.modifier_order(self.traces)

    def test_v2_omits_two_families_and_v3_exposes_all_eight(self):
        source = v2.balanced_order(self.traces)
        self.assertEqual({candidate.modifier(r) for r in source[:400]}, set(range(6)))
        ordered = self.order()
        self.assertEqual(len({r['id'] for r in ordered}), 1152)
        self.assertEqual(len({r['native_case_id'] for r in ordered[:576]}), 576)
        self.assertEqual([r['prompt'] for r in ordered[:12]], list(base.THEMES))
        for theme in base.THEMES:
            sample = [r for r in ordered[:400] if r['theme'] == theme]
            counts = Counter(candidate.modifier(r) for r in sample)
            self.assertEqual(set(counts), set(range(8)))
            self.assertLessEqual(max(counts.values()) - min(counts.values()), 1)
            forms = Counter(r['id'][-2:] for r in sample)
            self.assertLessEqual(abs(forms['p0'] - forms['p1']), 1)
        self.assertEqual(Counter(r['id'][-2:] for r in ordered[:400]),
                         {'p0': 200, 'p1': 200})
        self.assertEqual(len({r['group_id'] for r in ordered[:400]}), 72)
        self.assertEqual([r['id'] for r in self.order()], [r['id'] for r in ordered])

    def test_same_modifier_replay_protects_all_family_exposure(self):
        ordered = self.order()
        replay, replacements = candidate.replay_prefix(ordered)
        self.assertEqual(len(replacements), 24)
        self.assertEqual(len({r['native_case_id'] for r in replay}), 376)
        self.assertEqual(len({r['group_id'] for r in replay}), 72)
        self.assertEqual(Counter((r['theme'], candidate.modifier(r)) for r in replay),
                         Counter((r['theme'], candidate.modifier(r)) for r in ordered[:400]))
        self.assertEqual(Counter(r['theme'] for r in replay if r['prompt'] == r['theme']),
                         {t: 3 for t in base.THEMES})
        self.assertEqual(len({r['id'] for r in replay}) + 24, 400)
        self.assertTrue(all(candidate.modifier(next(r for r in ordered if r['id'] == d['displaced_id'])) == 0
                            for d in replacements))

    def test_source_identity_tamper_fails(self):
        row = next(iter(self.traces.values()))['p0']
        with self.assertRaisesRegex(ValueError, 'modifier/row identity'):
            candidate.modifier(dict(row, id='wrong-p0'))
        with self.assertRaisesRegex(ValueError, 'modifier/row identity'):
            candidate.modifier(dict(row, theme='unrelated'))
        with patch.object(candidate, 'V2_ORDER_SHA256', '0' * 64):
            with self.assertRaisesRegex(ValueError, 'source is not pinned'):
                candidate.modifier_order(self.traces)


class ArchiveCustodyTests(unittest.TestCase):
    def test_exact_native_archive_and_golden_recipe(self):
        folder = Path(os.environ.get('WB_ART_SLM_CORPUS_DIR', str(HERE)))
        required = ('train.jsonl', 'dev.jsonl', 'final.jsonl',
                    'native_cases.json', 'manifest.json', 'admission.json')
        if not all((folder / name).is_file() for name in required):
            self.skipTest('archived native-executed corpus not mounted')
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            result = candidate.build(folder, out)
            golden = json.loads((HERE / 'curriculum_modifier_replay_v3.json').read_text())
            self.assertEqual(result, golden)
            original = [json.loads(x) for x in (folder / 'train.jsonl').read_text().splitlines()]
            ordered = [json.loads(x) for x in (out / 'modifier_train.jsonl').read_text().splitlines()]
            source_indices = json.loads((out / 'replay_first400_source_indices.json').read_text())
            ordered_indices = json.loads((out / 'replay_first400_ordered_indices.json').read_text())
            self.assertEqual([original[i]['id'] for i in source_indices],
                             [ordered[i]['id'] for i in ordered_indices])
            self.assertEqual(base.digest((out / 'modifier_train.jsonl').read_bytes()),
                             golden['ordered_jsonl_sha256'])
            self.assertEqual(base.digest(base.canonical(json.loads(
                                 (out / 'replay_displacements.json').read_text()))),
                             golden['replay_400_displacements_sha256'])
            self.assertEqual(result['first_400_m6_m7_exposures'], 112)
            self.assertEqual(result['replay_unique_native_traces'], 376)


if __name__ == '__main__':
    unittest.main()