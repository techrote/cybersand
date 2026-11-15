"""Cheap adversarial regressions for the lane's exact-source CPU launcher."""
import unittest
from unittest.mock import patch
from pathlib import Path
from types import SimpleNamespace
from subprocess import CompletedProcess
from experiments.driv3r.stage_d.guidance import qualification as q


class QualificationTests(unittest.TestCase):
    def test_complete_pass(self):
        self.assertTrue(q.parse_unittest("Ran 168 tests in 3.00s\n\nOK\n", 0)["passed"])

    def test_missing_and_duplicate_footer(self):
        for log in ("OK\n", "Ran 168 tests in 1.0s\nRan 168 tests in 1.0s\nOK\n"):
            with self.subTest(log=log):
                self.assertFalse(q.parse_unittest(log, 0)["passed"])

    def test_incomplete_cohort(self):
        for count in (148, 158, 167):
            with self.subTest(count=count):
                self.assertFalse(q.parse_unittest(f"Ran {count} tests in 1.0s\n\nOK\n", 0)["passed"])

    def test_skips_are_not_passes(self):
        self.assertFalse(q.parse_unittest("Ran 168 tests in 1.0s\n\nOK (skipped=1)\n", 0)["passed"])

    def test_failed_returncode_is_not_pass(self):
        self.assertFalse(q.parse_unittest("Ran 168 tests in 1.0s\n\nOK\n", 1)["passed"])

    def test_failed_suite_is_not_pass(self):
        self.assertFalse(q.parse_unittest("Ran 168 tests in 1.0s\n\nFAILED (failures=1)\n", 1)["passed"])

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


    def _mock_qualification_git(self, *, dirty="", diff="experiments/driv3r/stage_d/guidance/qualification.py\n"):
        calls = []
        def fake_git(root, *args):
            calls.append(args)
            if args[:2] == ("rev-parse", "HEAD"):
                return CompletedProcess(args, 0, "a" * 40 + "\n", "")
            if args[:2] == ("merge-base", "--is-ancestor"):
                return CompletedProcess(args, 0, "", "")
            if args[0] == "status":
                return CompletedProcess(args, 0, dirty, "")
            if args[0] == "diff":
                return CompletedProcess(args, 0, diff, "")
            return CompletedProcess(args, 1, "", "unexpected git operation")
        return fake_git, calls

    def test_global_dirty_shared_source_rejected(self):
        git, calls = self._mock_qualification_git(
            dirty=" M experiments/driv3r/d_common/v1/runtime.py\n")
        digest = SimpleNamespace(hexdigest=lambda: q.M1_SCHEMA_SHA256)
        with patch.object(q, "_git", side_effect=git):
            with patch.object(Path, "read_bytes", return_value=b"schema"):
                with patch.object(q.hashlib, "sha256", return_value=digest):
                    with self.assertRaisesRegex(q.QualificationError, "Dirty worktree"):
                        q.source_fence(Path("/missing"))
        self.assertIn(("status", "--porcelain", "--untracked-files=all"), calls)

    def test_renamed_out_of_lane_source_rejected(self):
        git, calls = self._mock_qualification_git(
            diff="experiments/driv3r/d_common/v1/old.py\n"
                 "experiments/driv3r/stage_d/guidance/new.py\n")
        digest = SimpleNamespace(hexdigest=lambda: q.M1_SCHEMA_SHA256)
        with patch.object(q, "_git", side_effect=git):
            with patch.object(Path, "read_bytes", return_value=b"schema"):
                with patch.object(q.hashlib, "sha256", return_value=digest):
                    with self.assertRaisesRegex(q.QualificationError, "outside exclusive"):
                        q.source_fence(Path("/missing"))
        self.assertTrue(any(cmd[0] == "diff" and "--no-renames" in cmd
                            for cmd in calls))

if __name__ == "__main__":
    unittest.main()
