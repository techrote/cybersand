"""Adversarial evaluator receipts. Synthetic values are not gameplay evidence."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import qualify_workbench


class SourceCustodyTests(unittest.TestCase):
    def test_large_windows_tree_uses_bounded_git_arguments_and_rejects_dirty_source(self) -> None:
        paths = [f"godot/tests/qualification_source_{index:04d}_with_a_long_name.gd" for index in range(1400)]
        listing = ("\0".join(paths) + "\0").encode()
        with patch.object(qualify_workbench.subprocess, "check_output", side_effect=[listing, b""]) as command, \
                patch.object(qualify_workbench.runner, "sha256", return_value="a" * 64):
            self.assertEqual(len(qualify_workbench.committed_inputs()), len(paths))
            self.assertTrue(all(sum(len(arg) + 1 for arg in call.args[0]) < 1024 for call in command.call_args_list))
        with patch.object(qualify_workbench.subprocess, "check_output", side_effect=[listing, (paths[-1] + "\0").encode()]):
            with self.assertRaisesRegex(ValueError, "not committed"):
                qualify_workbench.committed_inputs()


class WorkbenchCompletionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = Path(self.directory.name) / "run.log"
        self.schema = "objectshard-m4-workbench-completion-v1"
        self.good = {"schema": self.schema, "checks": 70, "failures": []}

    def test_actual_footer_after_diagnostics_and_both_failure_encodings(self) -> None:
        for failures in ([], 0):
            receipt = {**self.good, "failures": failures}
            self.log.write_text("Diagnostic output\n" + json.dumps(receipt))
            self.assertEqual(qualify_workbench.completion(self.log, self.schema), receipt)

    def test_missing_duplicate_empty_failed_and_boolean_receipts_are_refused(self) -> None:
        mutations = ({"schema": "other"}, {"checks": 0}, {"checks": True}, {"failures": False},
                     {"failures": ["held native owner"]}, {"failures": 1})
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                self.log.write_text(json.dumps({**self.good, **mutation}))
                with self.assertRaises(ValueError):
                    qualify_workbench.completion(self.log, self.schema)
        self.log.write_text((json.dumps(self.good) + "\n") * 2)
        with self.assertRaises(ValueError):
            qualify_workbench.completion(self.log, self.schema)


class ActualWorkloadTests(unittest.TestCase):
    def profile(self, rendered: bool = False) -> dict:
        return {"source_commit": "a" * 40, "scene": "tower", "camera": "overview",
                "completed_semantic_ticks": 180, "actual_physics_steps": 720,
                "native_pose_acknowledgements": 720, "active_body_count_max": 1,
                "elapsed_usec": 10_000_000, "semantic_ticks_per_wall_second": 18.0,
                "shard_dimensions": [{"width": 48, "height": 64}],
                "active_body_cohorts": {"1": {"wall_usec": 1_000_000}},
                "display_driver": "windows" if rendered else "headless",
                "render_submissions": 120 if rendered else 0}

    def test_headless_and_graphical_custody_are_separate(self) -> None:
        for rendered in (False, True):
            qualify_workbench.validate_profile(self.profile(rendered), "a" * 40, rendered)

    def test_nonprogress_empty_physics_and_wrong_identity_are_refused(self) -> None:
        for mutation in ({"source_commit": "b" * 40}, {"scene": "lab"}, {"camera": "unknown"},
                         {"completed_semantic_ticks": 179}, {"actual_physics_steps": 0},
                         {"native_pose_acknowledgements": 0}, {"active_body_count_max": 0},
                         {"elapsed_usec": True}, {"semantic_ticks_per_wall_second": float("nan")},
                         {"shard_dimensions": []}, {"active_body_cohorts": {}}):
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                qualify_workbench.validate_profile({**self.profile(), **mutation}, "a" * 40, False)

    def test_headless_callbacks_cannot_be_relabelled_as_rendered_frames(self) -> None:
        value = self.profile()
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, True)
        value["render_submissions"] = 120
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, False)
        value = self.profile(True)
        value["render_submissions"] = 0
        with self.assertRaises(ValueError):
            qualify_workbench.validate_profile(value, "a" * 40, True)


if __name__ == "__main__":
    unittest.main()
