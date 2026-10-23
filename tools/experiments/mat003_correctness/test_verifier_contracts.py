"""Focused untimed MAT-003 verifier contract regressions."""
from pathlib import Path
import tempfile
import unittest

from negative import exercise


class VerifierContractTests(unittest.TestCase):
    def test_all_retained_negative_controls_and_repaired_resident_witnesses(self):
        with tempfile.TemporaryDirectory() as temporary:
            passed=exercise(Path(temporary)/"fixtures")
        self.assertEqual(len(passed),34)
        required={
            'resident-mixed-aged-unaged-positive',
            'resident-unaged-drift',
            'resident-missing-exclusion-drift',
            'resident-contradictory-exclusion-drift',
            'resident-block-owner-drift',
            'resident-post-clear-activity-drift',
            'resident-reentry-activity-drift',
            'excluded-sand-never-reentered',
            'world-decoder-bit-enumeration-crosscheck',
        }
        self.assertTrue(required.issubset(set(passed)))


if __name__=="__main__":
    unittest.main()
