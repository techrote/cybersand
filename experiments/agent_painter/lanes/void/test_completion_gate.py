"""Model-free negative controls for VOID's 120-step promotion gate."""
from __future__ import annotations

import unittest

from completion_gate import verify_completion


def completed() -> dict:
    return {
        "status": "completed", "global_step": 120,
        "checkpoint": "checkpoint-000120",
        "actual_training": True,
        "checkpoint_readback_exact": True,
        "frozen_base_unchanged": True,
    }


class CompletionGateTests(unittest.TestCase):
    def test_exact_completed_campaign_is_promotable(self):
        self.assertTrue(verify_completion(completed(), 0)["promotable"])

    def test_interrupted_40_step_with_valid_checkpoint_refused(self):
        partial = completed()
        partial.update(status="stopped-checkpoint-saved", global_step=40,
                       checkpoint="checkpoint-000040")
        with self.assertRaisesRegex(ValueError, "partial/failure"):
            verify_completion(partial, 2)
        with self.assertRaisesRegex(ValueError, "status"):
            verify_completion(partial, 0)

    def test_nonzero_exit_with_forged_completed_summary_refused(self):
        for code in (2, 1, 124, 137):
            with self.subTest(exit_code=code), self.assertRaises(ValueError):
                verify_completion(completed(), code)

    def test_all_positive_fields_are_required(self):
        for key, value in [
            ("status", "running"), ("global_step", 119),
            ("checkpoint", "checkpoint-000080"),
            ("actual_training", False),
            ("checkpoint_readback_exact", False),
            ("frozen_base_unchanged", False),
        ]:
            bad = completed()
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_completion(bad, 0)
            del bad[key]
            with self.subTest(key=key+" missing"), self.assertRaises(ValueError):
                verify_completion(bad, 0)

    def test_boolean_step_and_numeric_success_are_not_equivalent(self):
        bad = completed()
        bad["global_step"] = True
        with self.assertRaises(ValueError):
            verify_completion(bad, 0)
        bad = completed()
        bad["actual_training"] = 1
        with self.assertRaises(ValueError):
            verify_completion(bad, 0)


if __name__ == "__main__":
    unittest.main()
