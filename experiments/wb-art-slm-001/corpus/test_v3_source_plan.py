"""Offline source-index custody regressions (no model, FINAL or native execution)."""
import copy
import unittest

import v3_source_plan as plan

THEMES = ('coral','veins','ribs','mycelium','roots','strata','dunes','crystals',
          'honeycomb','labyrinth','ruins','circuitry')


def fixture():
    # Two phrasings x six structural groups x eight modifiers x twelve themes.
    # Reordered rows are purposefully different from the original archive order.
    ordered = []
    for cycle in range(48):
        for theme in THEMES:
            variant = cycle % 6
            modifier = cycle // 6
            trace = f'{theme}-v{variant}-m{modifier}-s{17 + modifier * 37}'
            form = 'p0' if cycle % 2 == 0 else 'p1'
            ordered.append({'id': f'{trace}-{form}', 'native_case_id': trace,
                            'theme': theme, 'group_id': f'{theme}:v{variant}',
                            'prompt': theme if cycle == 0 else f'{theme} other',
                            'completion': f'{{"theme":"{theme}"}}', 'split': 'train'})
    ordered += [dict(r, id=r['id'][:-2] + ('p1' if r['id'].endswith('p0') else 'p0'),
                     prompt=f'{r["theme"]} alternative') for r in ordered]
    source = list(reversed(ordered))
    by_id = {r['id']: i for i, r in enumerate(source)}
    draw_ids = list(range(400))
    for theme in THEMES:
        # Every theme receives three literal draws, with exactly 24 displacements.
        anchor = next(i for i, row in enumerate(ordered[:12]) if row['theme'] == theme)
        occupied = [i for i in range(12, 400) if ordered[i]['theme'] == theme][:2]
        for pos in occupied:
            draw_ids[pos] = anchor
    src = [by_id[ordered[i]['id']] for i in draw_ids]
    dest = draw_ids
    draws = [ordered[i] for i in draw_ids]
    from collections import Counter
    mods = Counter(r['native_case_id'].split('-m')[1].split('-')[0] for r in draws)
    per_theme = {t: {str(m): sum(r['theme'] == t and f'-m{m}-' in r['native_case_id']
                                  for r in draws) for m in range(8)} for t in THEMES}
    recorded = {
        'ordered_ids_sha256': plan.ids_hash(ordered),
        'replay_400_source_indices_sha256': plan.index_hash(src),
        'replay_400_ordered_indices_sha256': plan.index_hash(dest),
        'replay_400_ids_sha256': plan.ids_hash(draws),
        'modifier_counts': dict(sorted(mods.items())),
        'per_theme_modifier_counts': per_theme,
        'phrasing_counts': dict(sorted(Counter(r['id'][-2:] for r in draws).items())),
        'train_sha256': 'a'*64, 'ordered_jsonl_sha256': 'b'*64,
        'compiler_sha256': 'c'*64, 'native_source': 'd'*40,
    }
    return source, ordered, src, dest, recorded


class SourcePlanTests(unittest.TestCase):
    def setUp(self):
        self.source, self.ordered, self.src, self.dest, self.m = fixture()

    def validate(self, **kwargs):
        return plan.validated_plan(kwargs.get('source', self.source),
                                   kwargs.get('ordered', self.ordered),
                                   kwargs.get('src', self.src),
                                   kwargs.get('dest', self.dest),
                                   kwargs.get('recorded', self.m))

    def test_valid_independent_source_space(self):
        p = self.validate()
        self.assertEqual(p['indices'], self.src)
        self.assertEqual(p['draws'], 400)
        self.assertEqual(p['unique_native_traces'], 376)
        self.assertEqual(p['source_file'], 'train.jsonl')
        self.assertNotEqual(self.src, self.dest)
        self.assertEqual(len(set(self.src)), 376)

    def test_source_vs_ordered_index_confusion_fails(self):
        with self.assertRaisesRegex(ValueError, 'digest|index-space'):
            self.validate(src=self.dest)
        with self.assertRaisesRegex(ValueError, 'digest|index-space'):
            self.validate(dest=self.src)

    def test_same_id_changed_completion_fails(self):
        altered = copy.deepcopy(self.ordered)
        altered[0]['completion'] = '{"theme":"wrong"}'
        with self.assertRaisesRegex(ValueError, 'target/receipt'):
            self.validate(ordered=altered)

    def test_stale_digest_fails(self):
        altered = dict(self.m, replay_400_ids_sha256='0' * 64)
        with self.assertRaisesRegex(ValueError, 'draw IDs'):
            self.validate(recorded=altered)

    def test_non_integer_or_out_of_bounds_rejected(self):
        for invalid in (True, -1, 1152, '15'):
            bad = list(self.src)
            bad[0] = invalid
            # Keep the hash in sync to ensure type/range rejection itself works.
            altered = dict(self.m, replay_400_source_indices_sha256=plan.index_hash(bad))
            with self.assertRaisesRegex(ValueError, 'invalid replay index'):
                self.validate(src=bad, recorded=altered)

    def test_native_theme_or_exposure_tamper_fails(self):
        altered = copy.deepcopy(self.ordered)
        altered[0]['native_case_id'] = 'ribs-v0-m0-s17'
        amended = copy.deepcopy(self.source)
        for row in amended:
            if row['id'] == altered[0]['id']:
                row['native_case_id'] = altered[0]['native_case_id']
        with self.assertRaisesRegex(ValueError, 'native-trace exposure'):
            self.validate(source=amended, ordered=altered)

    def test_changed_original_source_membership_fails(self):
        altered = copy.deepcopy(self.source)
        altered[0]['id'] = 'extra-copy-p0'
        with self.assertRaisesRegex(ValueError, 'membership'):
            self.validate(source=altered)


if __name__ == '__main__':
    unittest.main()
