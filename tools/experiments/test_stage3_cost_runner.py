import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_stage3_cost import RESULT_SCHEMA, case, validate_value


class Stage3CostValidationTests(unittest.TestCase):
    def base(self, arm='connectivity'):
        expected = case(arm, 'wall', 64, 1, 2, 2)
        value = {**expected, 'schema': RESULT_SCHEMA, 'valid': True,
                 'producer': None if arm == 'current' else {},
                 'journal': None if arm == 'current' else {},
                 'connectivity': {} if arm == 'connectivity' else None,
                 'region_storage_bytes': 1 if arm == 'connectivity' else 0}
        return expected, value

    def test_accepts_exact_connectivity_identity(self):
        expected, value = self.base()
        self.assertIs(validate_value(expected, value), value)

    def test_rejects_current_zero_counter_fabrication(self):
        expected, value = self.base('current')
        value['producer'] = {}
        with self.assertRaisesRegex(ValueError, 'fabricated'):
            validate_value(expected, value)

    def test_rejects_identity_mismatch(self):
        expected, value = self.base()
        changed = copy.deepcopy(value)
        changed['workers'] = 4
        with self.assertRaisesRegex(ValueError, 'identity'):
            validate_value(expected, changed)

    def test_rejects_missing_connectivity_storage(self):
        expected, value = self.base()
        value['region_storage_bytes'] = 0
        with self.assertRaisesRegex(ValueError, 'storage'):
            validate_value(expected, value)


if __name__ == '__main__':
    unittest.main()
