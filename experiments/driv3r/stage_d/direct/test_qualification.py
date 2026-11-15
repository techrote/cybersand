"""Fail-closed exact-head qualification launcher regressions; no native run."""
import unittest
from unittest.mock import patch
from pathlib import Path
from subprocess import CompletedProcess
from experiments.driv3r.stage_d.direct import qualification as q


class QualificationTests(unittest.TestCase):
    def test_complete_suite_footer(self):
        self.assertTrue(q.parse_unittest_result("Ran 130 tests in 2.001s\n\nOK\n", 0)["passed"])

    def test_short_suite_never_qualifies(self):
        self.assertFalse(q.parse_unittest_result("Ran 121 tests in 1.0s\n\nOK\n", 0)["passed"])

    def test_failure_never_qualifies(self):
        self.assertFalse(q.parse_unittest_result("Ran 130 tests in 1.0s\n\nFAILED (failures=1)\n", 1)["passed"])

    def test_skip_never_qualifies(self):
        self.assertFalse(q.parse_unittest_result("Ran 130 tests in 1.0s\n\nOK (skipped=1)\n", 0)["passed"])

    def test_unparseable_or_duplicate_footer_refused(self):
        for content in ("OK\n", "Ran 130 tests in 1.0s\nRan 131 tests in 1.0s\nOK\n"):
            with self.subTest(content=content):
                self.assertFalse(q.parse_unittest_result(content, 0)["passed"])

    def test_dirty_worktree_refused_before_tests(self):
        def fake_git(root, *args):
            if args[0] == "rev-parse":
                return CompletedProcess(args, 0, "a" * 40 + "\n", "")
            if args[0] == "merge-base":
                return CompletedProcess(args, 0, "", "")
            return CompletedProcess(args, 0, " M experiments/driv3r/stage_d/direct/paired.py\n", "")
        with patch.object(q, "_git", side_effect=fake_git), patch.object(q, "assert_approved_schema") as schema:
            with self.assertRaisesRegex(q.QualificationError, "dirty"):
                q.source_fence(Path("/unused"))
            schema.assert_not_called()

    def test_nonancestor_m1_refused_before_tests(self):
        def fake_git(root, *args):
            return (CompletedProcess(args, 0, "a" * 40 + "\n", "") if args[0] == "rev-parse"
                    else CompletedProcess(args, 1, "", "not ancestor"))
        with patch.object(q, "_git", side_effect=fake_git):
            with self.assertRaisesRegex(q.QualificationError, "not an ancestor"):
                q.source_fence(Path("/unused"))

    def test_timeout_bounds_are_strict(self):
        for value in (True, 0, 601, 1.5, "3"):
            with self.subTest(value=value):
                with self.assertRaisesRegex(q.QualificationError, "timeout"):
                    q.run_qualification(Path("/unused"), value)


    def test_dirty_shared_or_untracked_source_refused(self):
        def fake_git(root, *args):
            if args[0] == "rev-parse":
                return CompletedProcess(args, 0, "a" * 40 + "\n", "")
            if args[0] == "merge-base":
                return CompletedProcess(args, 0, "", "")
            return CompletedProcess(args, 0, "?? experiments/driv3r/d_common/untracked.py\n", "")
        with patch.object(q, "_git", side_effect=fake_git), patch.object(q, "assert_approved_schema") as schema:
            with self.assertRaisesRegex(q.QualificationError, "dirty"):
                q.source_fence(Path("/unused"))
            schema.assert_not_called()

    def test_committed_nonlane_changes_refused_even_with_clean_worktree(self):
        def fake_git(root, *args):
            if args[0] == "rev-parse":
                return CompletedProcess(args, 0, "a" * 40 + "\n", "")
            if args[0] == "merge-base":
                return CompletedProcess(args, 0, "", "")
            if args[0] == "status":
                return CompletedProcess(args, 0, "", "")
            return CompletedProcess(args, 0, "experiments/driv3r/d_common/v1/validator.py\n", "")
        with patch.object(q, "_git", side_effect=fake_git), patch.object(q, "assert_approved_schema") as schema:
            with self.assertRaisesRegex(q.QualificationError, "outside D-1A lane"):
                q.source_fence(Path("/unused"))
            schema.assert_not_called()


if __name__ == "__main__":
    unittest.main()
