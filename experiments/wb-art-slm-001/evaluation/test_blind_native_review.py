"""Synthetic score adversaries; --packet additionally runs the real frozen native stimulus build."""
import argparse
from pathlib import Path
import json
import tempfile
import unittest
from blind_native_review import THEMES, build, score


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        key = {'schema_version': 1, 'review_token': 'fixed-candidate',
               'scope': 'synthetic-not-native', 'candidate': 'synthetic',
               'original_requests': 5, 'first_pass_rejected': 1,
               'excluded': [{'group_id': 'g3', 'theme': 'coral'}],
               'items': [{'id': 'q001', 'group_id': 'g1', 'theme': 'roots', 'cohort': 'development'},
                         {'id': 'q002', 'group_id': 'g1', 'theme': 'roots', 'cohort': 'development'},
                         {'id': 'q003', 'prediction_id': 'keyword-ribs', 'group_id': 'g2', 'theme': 'ribs', 'cohort': 'keyword',
                          'symbolic_theme_correct': False, 'symbolic_motif_correct': True},
                         {'id': 'q004', 'group_id': 'g4', 'theme': 'veins', 'cohort': 'keyword'}]}
        self.key = self.root / 'key.json'
        self.key.write_text(json.dumps(key))
        self.data = {'schema_version': 1, 'review_token': 'fixed-candidate', 'rows': [
            {'id': 'q001', 'label': 'roots', 'quality': '4', 'variety': '2'},
            {'id': 'q002', 'label': 'roots', 'quality': '', 'variety': ''},
            {'id': 'q003', 'label': 'ruins', 'quality': '3', 'variety': '1'},
            {'id': 'q004', 'label': 'unsure', 'quality': '', 'variety': ''}]}
        self.responses = self.root / 'responses.json'

    def tearDown(self):
        self.tmp.cleanup()

    def run_score(self, data=None):
        self.responses.write_text(json.dumps(self.data if data is None else data))
        return score(self.key, self.responses)

    def test_denominator_and_group_macro(self):
        out = self.run_score()
        self.assertEqual(out['conditional_native_image_recognition']['matched'], 2)
        self.assertEqual(out['conditional_native_image_recognition']['admitted_requests'], 4)
        self.assertEqual(out['end_to_end_all_original_requests']['requests'], 5)
        self.assertEqual(out['structural_group_macro_accuracy']['groups'], 3)
        self.assertEqual(out['structural_group_macro_accuracy']['pct'], 33.333)
        self.assertEqual(out['all_original_structural_groups']['groups'], 4)
        self.assertEqual(out['all_original_structural_groups']['macro_pct'], 25.0)
        self.assertEqual(out['subjective_quality_1to5']['ratings'], 2)
        self.assertEqual(out['threshold_80_pct'], 'PROVISIONAL_RATER_ONLY')
        self.assertEqual(out['go_no_go'], 'HOLD')
        self.assertEqual(out['symbolic_failures_despite_native_pass'][0]['prediction_id'], 'keyword-ribs')
        self.assertEqual(len(out['blind_theme_confusions']), 2)

    def test_partial_is_never_promotion(self):
        data = json.loads(json.dumps(self.data))
        data['rows'][0]['label'] = ''
        out = self.run_score(data)
        self.assertEqual(out['state'], 'INCOMPLETE')
        self.assertEqual(out['go_no_go'], 'HOLD')

    def test_adverse_responses(self):
        for name, mutation in [
            ('candidate token', lambda d: d.update(review_token='other')),
            ('duplicate', lambda d: d['rows'][1].update(id='q001')),
            ('unrecognized label', lambda d: d['rows'][1].update(label='evil')),
            ('invalid rating', lambda d: d['rows'][1].update(variety='6')),
            ('missing row', lambda d: d['rows'].pop()),
            ('extra row', lambda d: d['rows'].append(dict(d['rows'][0], id='q999'))),
        ]:
            with self.subTest(name=name):
                d = json.loads(json.dumps(self.data)); mutation(d)
                with self.assertRaises(ValueError):
                    self.run_score(d)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--packet', type=Path)
    a = p.parse_args()
    unittest.main(argv=['test_blind_native_review.py'], exit=False)
    if a.packet:
        with tempfile.TemporaryDirectory() as tmp:
            result = build(a.packet, Path(tmp) / 'blind')
            assert result['review_pairs'] == 34 and result['image_count'] == 68
            print('genuine archived native packet build: 34 pairs; 68 custody-bound images; 2 refused')
