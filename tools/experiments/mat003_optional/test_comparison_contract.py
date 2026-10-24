"""Small contract tests; archived platform replay is a separate evidence class."""
import copy
import hashlib
import json
from pathlib import Path
import unittest

from comparison_contract import authenticate_comparator, compare_result, RESULT_FIELDS

ROOT = Path(__file__).resolve().parents[3]
RECORDS = ROOT / 'docs/audits/mat003-overnight-2026-10-24'
SUMMARY_SEALS = {
    'optional': '8c559c9975bc8535227eecf86d502d736bcc2fba0bf6d0b5c53a7f860bbd1c1d',
    'touch': 'e49d594235142005cc75be87d8108edae6fab151848737b41fd6a10603e93e18',
}


class ComparisonContracts(unittest.TestCase):
    def setUp(self):
        self.records = {kind: json.loads((RECORDS / (kind + '-summary.json')).read_bytes())
                        for kind in RESULT_FIELDS}

    def test_published_comparators_match_external_byte_and_semantic_seals(self):
        for kind, record in self.records.items():
            self.assertEqual(hashlib.sha256((RECORDS / (kind + '-summary.json')).read_bytes()).hexdigest(), SUMMARY_SEALS[kind])
            authenticate_comparator(kind, record)
            authenticate_comparator(kind, json.loads(json.dumps(record, indent=1)))

    def test_substituted_values_metadata_and_missing_comparators_are_refused(self):
        for kind, record in self.records.items():
            for mutation in ('case', 'metadata', 'missing'):
                value = copy.deepcopy(record)
                if mutation == 'case': value['cases'][0]['checks'] += 1
                elif mutation == 'metadata': value['source_commit'] = '0' * 40
                else: value = None
                with self.subTest(kind=kind, mutation=mutation), self.assertRaisesRegex(ValueError, 'comparator identity'):
                    authenticate_comparator(kind, value)

    def test_every_required_field_and_extra_field_are_checked(self):
        for kind, fields in RESULT_FIELDS.items():
            win = self.records[kind]['cases'][0]
            data = {k: win[k] for k in fields}
            compare_result(kind, data, win)
            for key in fields:
                missing = dict(data); del missing[key]
                with self.subTest(kind=kind, missing=key), self.assertRaisesRegex(ValueError, 'result schema'):
                    compare_result(kind, missing, win)
                changed = copy.deepcopy(data)
                changed[key] = not data[key] if type(data[key]) is bool else None
                with self.subTest(kind=kind, changed=key), self.assertRaises(ValueError):
                    compare_result(kind, changed, win)
            with self.assertRaisesRegex(ValueError, 'result schema'):
                compare_result(kind, dict(data, extra=0), win)

    def test_wasm_exceptions_are_required_and_explicitly_bounded(self):
        win = self.records['optional']['cases'][0]
        data = {k: win[k] for k in RESULT_FIELDS['optional']}
        data.update(owner_object_size=72, pointer_capacity_bytes=data['resident_owners'] * 4)
        compare_result('optional', data, win, wasm=True)
        for field in ('owner_object_size', 'pointer_capacity_bytes'):
            changed = dict(data); changed[field] += 1
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'Wasm32'):
                compare_result('optional', changed, win, wasm=True)
        with self.assertRaises(ValueError):
            compare_result('optional', data, win)  # No ABI exceptions on Linux.


if __name__ == '__main__':
    unittest.main()
