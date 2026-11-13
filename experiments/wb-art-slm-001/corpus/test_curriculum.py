"""Corpus-owned controls for the literal-first, source-admitted replay order."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from collections import Counter

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('build_curriculum', HERE / 'build_curriculum.py')
CURRICULUM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CURRICULUM)


class CurriculumOrderTests(unittest.TestCase):
    def setUp(self):
        self.traces = {}
        for theme in CURRICULUM.THEMES:
            for variant in range(6):
                for modifier in range(8):
                    trace = f'{theme}-v{variant}-m{modifier}-s{17+modifier}'
                    program = {'theme': theme, 'layers': [{'motif': 'network', 'layout': 'center'}]}
                    self.traces[trace] = {
                        phrase: {'id': trace + '-' + phrase, 'native_case_id': trace,
                                 'group_id': f'{theme}:v{variant}', 'theme': theme,
                                 'prompt': theme if variant == 0 and modifier == 0 and phrase == 'p0' else 'other',
                                 'completion': json.dumps(program)}
                        for phrase in ('p0', 'p1')}

    def test_balanced_unique_400_and_early_literal_words(self):
        r = CURRICULUM.order_rows(self.traces)
        self.assertEqual(len(r), 1152)
        self.assertEqual([x['prompt'] for x in r[:12]], list(CURRICULUM.THEMES))
        self.assertEqual(len(set(x['native_case_id'] for x in r[:576])), 576)
        self.assertEqual(len(set(x['id'] for x in r)), 1152)
        self.assertEqual(Counter(x['id'].rsplit('-', 1)[-1] for x in r[:400]),
                         {'p0': 200, 'p1': 200})
        self.assertEqual(sorted(Counter(x['theme'] for x in r[:400]).values()),
                         [33]*8 + [34]*4)
        self.assertEqual(len({x['group_id'] for x in r[:400]}), 72)
        self.assertEqual([x['id'] for x in CURRICULUM.order_rows(self.traces)],
                         [x['id'] for x in r])

    def test_reject_missing_structure_group(self):
        self.traces.pop(next(iter(self.traces)))
        with self.assertRaisesRegex(ValueError, 'structural-group cardinality'):
            CURRICULUM.order_rows(self.traces)


class ArchivedSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not all((HERE / name).is_file() for name in
                   ('train.jsonl', 'dev.jsonl', 'final.jsonl', 'native_cases.json',
                    'manifest.json', 'admission.json')):
            raise unittest.SkipTest('executed corpus archive not materialized; synthetic guards still run')

    def test_pinned_manifest_and_order_matches_checked_in_recipe(self):
        with tempfile.TemporaryDirectory() as tmp:
            recipe = CURRICULUM.build(HERE, Path(tmp))
            expected = json.loads((HERE / 'curriculum_literal_replay_v1.json').read_text())
            self.assertEqual(recipe, expected)
            self.assertEqual(CURRICULUM.digest((Path(tmp) / 'ordered_train.jsonl').read_bytes()),
                             expected['ordered_train_sha256'])

    def test_reject_modified_training_rows_without_repair(self):
        # A temporary directory with all unchanged files linked, and a modified
        # train file. The source custody gate must fire before admission.
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)
            for name in ('train.jsonl', 'dev.jsonl', 'final.jsonl', 'native_cases.json',
                         'manifest.json', 'admission.json'):
                (dest / name).symlink_to(HERE / name)
            data = (HERE / 'train.jsonl').read_bytes()
            (dest / 'train.jsonl').unlink()
            (dest / 'train.jsonl').write_bytes(data.replace(b'"theme":"roots"', b'"theme":"ruins"', 1))
            with self.assertRaisesRegex(ValueError, 'changed train file'):
                CURRICULUM.load_and_verify(dest)


if __name__ == '__main__':
    unittest.main()
