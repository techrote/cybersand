import unittest
from export_gcr_evidence import mechanism_counts


class MissingLedgerCoverage(unittest.TestCase):
    def test_unacquired_support_remains_unknown(self):
        counts = mechanism_counts({'mode': 'synchronous', 'candidate': 'GCR', 'rows': []})
        self.assertEqual(counts['native_ledger_boundaries'], 0)
        self.assertIsNone(counts['supported_native_boundaries'])
        self.assertIsNone(counts['positive_normal_native_boundaries'])

    def test_acquired_zero_support_is_measured_zero(self):
        counts = mechanism_counts({'mode': 'synchronous', 'candidate': 'GCR',
                                   'rows': [{'tick': 1, 'gcr': {'bins': 0, 'normal_accepted': 0}}]})
        self.assertEqual(counts['native_ledger_boundaries'], 1)
        self.assertEqual(counts['supported_native_boundaries'], 0)
        self.assertEqual(counts['positive_normal_native_boundaries'], 0)


if __name__ == '__main__':
    unittest.main()
