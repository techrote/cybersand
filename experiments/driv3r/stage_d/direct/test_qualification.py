"""Fail-closed exact-head qualification launcher regressions; no native run."""
import unittest
from unittest.mock import patch
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
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


    def test_git_detected_rename_cannot_hide_shared_m1_deletion(self):
        # On normal Git defaults, --name-only reports ONLY the destination
        # for a 100% identical rename. That would make a removed common
        # contract look like a permitted direct-lane-only addition.
        with TemporaryDirectory() as tmp:
            root = Path(tmp)

            def git(*args):
                return subprocess.run(
                    ("git", *args), cwd=root, check=True,
                    text=True, capture_output=True)

            git("init", "-q")
            git("config", "user.name", "D-1A offline fixture")
            git("config", "user.email", "d1a-test@example.invalid")
            git("config", "diff.renames", "true")
            common = Path("experiments/driv3r/d_common/v1/m1_contract.py")
            (root / common).parent.mkdir(parents=True)
            (root / common).write_text(
                "# Immutable shared-source fixture\\n"
                "SCHEMA = 'v1 approved contract'\\n" * 6, encoding="utf-8")
            git("add", ".")
            git("commit", "-qm", "frozen synthetic M1 base")
            m1 = git("rev-parse", "HEAD").stdout.strip()

            destination = Path(q.LANE) / "disguised_contract.py"
            (root / destination).parent.mkdir(parents=True)
            git("mv", common.as_posix(), destination.as_posix())
            git("commit", "-qm", "move protected M1 file into lane")

            # Prove the original unprotected command really is vulnerable.
            self.assertEqual(
                git("diff", "--name-only", m1, "HEAD").stdout.strip(),
                destination.as_posix())
            with patch.object(q, "M1_SOURCE_COMMIT", m1), patch.object(
                    q, "assert_approved_schema") as schema:
                with self.assertRaisesRegex(
                        q.QualificationError, "outside D-1A lane"):
                    q.source_fence(root)
                schema.assert_not_called()

    def test_actual_git_lane_only_commit_remains_admissible(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)

            def git(*args):
                return subprocess.run(
                    ("git", *args), cwd=root, check=True,
                    text=True, capture_output=True)

            git("init", "-q")
            git("config", "user.name", "D-1A offline fixture")
            git("config", "user.email", "d1a-test@example.invalid")
            common = root / "experiments/driv3r/d_common/v1/contract.txt"
            common.parent.mkdir(parents=True)
            common.write_text("immutable original", encoding="utf-8")
            git("add", ".")
            git("commit", "-qm", "frozen synthetic M1 base")
            m1 = git("rev-parse", "HEAD").stdout.strip()

            direct = root / q.LANE / "new_only.py"
            direct.parent.mkdir(parents=True)
            direct.write_text("SAFE = True\\n", encoding="utf-8")
            git("add", ".")
            git("commit", "-qm", "new direct-lane addition")
            head = git("rev-parse", "HEAD").stdout.strip()
            with patch.object(q, "M1_SOURCE_COMMIT", m1), patch.object(
                    q, "assert_approved_schema") as schema:
                self.assertEqual(q.source_fence(root), head)
                schema.assert_called_once_with(root)



if __name__ == "__main__":
    unittest.main()
