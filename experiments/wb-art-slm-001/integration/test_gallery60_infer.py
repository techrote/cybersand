#!/usr/bin/env python3
"""Model-free checks of the frozen cohort and generated native-replay request boundaries."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gallery60_infer as mod


def synthetic_cohort():
    return {'state': 'FROZEN_BEFORE_NEW_MODEL_PREDICTIONS', 'request_count': 60,
            'themes': list(mod.THEMES), 'variants': list(mod.VARIANTS),
            'host_context': {'focus_width': 96, 'focus_height': 96, 'material_id': 58, 'seeds': [17, 73]},
            'requests': [{'id': f'g1-{i:02d}-{j}', 'theme': theme, 'variant': variant,
                          'prompt': theme + ' ' + variant}
                         for i, theme in enumerate(mod.THEMES, 1)
                         for j, variant in enumerate(mod.VARIANTS, 1)]}


class FrozenRequestTests(unittest.TestCase):
    def checked(self, data):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'frozen.json'
            raw = json.dumps(data, indent=2).encode()
            p.write_bytes(raw)
            old = mod.FROZEN_GALLERY_GIT_BLOB
            try:
                mod.FROZEN_GALLERY_GIT_BLOB = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
                return mod.frozen_cohort(p)
            finally:
                mod.FROZEN_GALLERY_GIT_BLOB = old

    def test_60_per_theme_and_variant(self):
        data, digest = self.checked(synthetic_cohort())
        self.assertEqual(len(data['requests']), 60)
        self.assertEqual(len(digest), 64)

    def test_duplicate_request_refused(self):
        data = synthetic_cohort()
        data['requests'][1]['id'] = data['requests'][0]['id']
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            self.checked(data)

    def test_wrong_seed_refused(self):
        data = synthetic_cohort()
        data['host_context']['seeds'] = [17, 74]
        with self.assertRaisesRegex(ValueError, 'seed'):
            self.checked(data)

    def test_wrong_host_material_refused(self):
        data = synthetic_cohort()
        data['host_context']['material_id'] = 0
        with self.assertRaisesRegex(ValueError, 'material'):
            self.checked(data)

    def test_changed_sha_refused_before_model_load(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'frozen.json'
            p.write_text(json.dumps(synthetic_cohort()))
            with self.assertRaisesRegex(ValueError, 'Git blob'):
                mod.frozen_cohort(p)

    def test_native_case_aliases_under_save_limit(self):
        if not (mod.TRAINING / 'export_native_cases.py').exists():
            self.skipTest('Role-owned Training module unavailable in isolated local smoke')
        import export_native_cases
        class FakeCompiler:
            @staticmethod
            def compile_with_report(program, width, height, seed, **kwargs):
                return {'width': width, 'height': height, 'seed': seed,
                        'operations': [{'shape': 'rectangle', 'x0': 1, 'y0': 1,
                                        'x1': 2, 'y1': 2, 'material': 58}]}
        request = synthetic_cohort()['requests'][0]
        cases, aliases = mod.native_cases_for({'theme': 'roots'}, request, FakeCompiler(), 'newv5')
        self.assertEqual(len(cases), 2)
        self.assertEqual({c['seed'] for c in cases}, {17, 73})
        self.assertEqual(set(aliases), {c['id'] for c in cases})
        self.assertTrue(all(len(c['id']) <= 38 for c in cases))
        self.assertTrue(all(c['prediction_id'] == request['id'] for c in cases))


if __name__ == '__main__':
    unittest.main()