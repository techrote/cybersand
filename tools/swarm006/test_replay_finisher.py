#!/usr/bin/env python3
"""Acceptance predicates and custody failures for revealed-corpus replay."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import replay_finisher as replay


class ReplayQualification(unittest.TestCase):
    def test_registered_corpus_and_helpers_are_unchanged(self):
        plan = replay.registered_plan()
        self.assertEqual(len(plan["cases"]) * len(plan["policies"]), 1920)
        self.assertEqual(len({c["seed"] for c in plan["cases"]}), 96)
        self.assertEqual(replay.frozen_runner().REGISTERED_LIMITS, plan["limits"])
        self.assertNotIn("unseen", replay.CLASSIFICATION)

    def test_revealed_registration_is_never_rewritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "registration.json"
            changed = replay.registered_plan()
            changed["candidate"]["git_sha"] = "0" * 40
            path.write_text(json.dumps(changed))
            with patch.object(replay, "REGISTRATION", path):
                with self.assertRaisesRegex(ValueError, "historical registration changed"):
                    replay.registered_plan()

    def test_joint_witness_is_not_apply_or_original_obligation_closure(self):
        row = {"execution": {"returncode": 0, "timed_out": False, "cancelled": False, "child_reaped": True},
               "status": "complete", "can_apply": True, "closure_evaluated": True,
               "still_required": 0, "qualified_joints": 1, "original_foreign_joined": 0}
        self.assertTrue(replay.endpoint(row, True))
        for key, value in (("status", "blocked"), ("status", "exhausted"), ("can_apply", False),
                           ("closure_evaluated", False), ("still_required", None),
                           ("still_required", 1), ("evidence_error", "malformed output")):
            altered = dict(row, **{key: value})
            self.assertFalse(replay.endpoint(altered, True), (key, value))
        for key, value in (("returncode", -11), ("returncode", 1), ("timed_out", True), ("cancelled", True), ("child_reaped", False)):
            altered = copy.deepcopy(row)
            altered["execution"][key] = value
            self.assertFalse(replay.endpoint(altered, True))
        row["qualified_joints"] = 0
        self.assertTrue(replay.endpoint(row))
        self.assertFalse(replay.endpoint(row, True))

    def test_dirty_or_failed_build_is_not_qualified(self):
        runner = replay.frozen_runner()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            base = {"source_root": str(path), "result": "PASS", "variant": "swarm006",
                    "source_dirty": "", "allow_dirty_requested": False, "source_custody_revalidated": True}
            for key, value in (("result", "FAIL"), ("source_dirty", " M mosaic_recovery.cpp"),
                               ("allow_dirty_requested", True), ("source_custody_revalidated", False)):
                (path / "build.json").write_text(json.dumps(dict(base, **{key: value})))
                with self.assertRaisesRegex(ValueError, "exact clean successful"):
                    replay.verified_build(path, runner)


if __name__ == "__main__":
    unittest.main()
