"""Cheap adversarial regressions for the lane's exact-source CPU launcher."""
import unittest
from unittest.mock import patch
from pathlib import Path
from subprocess import CompletedProcess
from experiments.driv3r.stage_d.guidance import qualification as q


class QualificationTests(unittest.TestCase):
    def test_complete_pass(self):
        self.assertTrue(q.parse_unittest("Ran 158 tests in 3.00s\n\nOK\n", 0)["passed"])

    def test_missing_and_duplicate_footer(self):
        for log in ("OK\n", "Ran 158 tests in 1.0s\nRan 158 tests in 1.0s\nOK\n"):
            with self.subTest(log=log):
                self.assertFalse(q.parse_unittest(log, 0)["passed"])

    def test_incomplete_cohort(self):
        self.assertFalse(q.parse_unittest("Ran 148 tests in 1.0s\n\nOK\n", 0)["passed"])

    def test_skips_are_not_passes(self):
        self.assertFalse(q.parse_unittest("Ran 158 tests in 1.0s\n\nOK (skipped=1)\n", 0)["passed"])

    def test_failed_returncode_is_not_pass(self):
        self.assertFalse(q.parse_unittest("Ran 158 tests in 1.0s\n\nOK\n", 1)["passed"])

    def test_failed_suite_is_not_pass(self):
        self.assertFalse(q.parse_unittest("Ran 158 tests in 1.0s\n\nFAILED (failures=1)\n", 1)["passed"])

    def test_invalid_timeout_fails_before_access(self):
        for t in (True, 0, -1, 601, 3.1, "180"):
            with self.subTest(t=t):
                with self.assertRaisesRegex(q.QualificationError, "Timeout"):
                    q.run_qualification(Path("/missing"), t)

    def test_unaccepted_ancestry_rejected(self):
        def git(root, *args):
            if args[0] == "rev-parse":
                return CompletedProcess(args, 0, "a" * 40 + "\n", "")
            return CompletedProcess(args, 1, "", "not ancestor")
        with patch.object(q, "_git", side_effect=git):
            with self.assertRaisesRegex(q.QualificationError, "not an ancestor"):
                q.source_fence(Path("/missing"))


if __name__ == "__main__":
    unittest.main()
