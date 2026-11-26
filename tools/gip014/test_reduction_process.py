"""Synthetic acceptance/resource controls; these never establish game defects."""
import copy
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import minimize
import owned_process
from test_evidence import ACTIONS, tape
from verify_transcript import summarize


class ReductionAcceptanceControls(unittest.TestCase):
    def run_probe(self, original, callback, **options):
        return minimize.minimize(original, callback, max_attempts=4, repeats=1,
                                 allow_unit_fixture=True, simplify_parameters=False, **options)

    def test_timeout_cannot_confirm_retained_failure(self):
        def replay(actions):
            value = tape(actions)
            value["summary"]["termination"] = "timeout"
            value["summary"] = summarize(value)
            return value
        result = self.run_probe(tape(ACTIONS), replay)
        self.assertEqual(result["status"], "original_not_repeatable")
        self.assertEqual(result["attempts"][0]["status"], "not_reproduced")

    def test_incomplete_original_is_never_a_reduction_target(self):
        for injected in (False, True):
            original = tape(ACTIONS, injected=injected)
            original["summary"]["termination"] = "timeout"
            original["summary"] = summarize(original)
            calls = []
            result = self.run_probe(original, lambda actions: calls.append(actions), target_outcome=True)
            self.assertEqual(result["status"], "original_incomplete")
            self.assertEqual(calls, [])

    def test_target_admission_status_and_classification_must_survive(self):
        for mutate in (lambda row: row["admission"].update(accepted=False),
                       lambda row: row.update(status="refused"),
                       lambda row: row.update(classification="expected_refusal")):
            def replay(actions):
                value = tape(actions)
                mutate(value["steps"][-1])
                value["summary"] = summarize(value)
                return value
            result = self.run_probe(tape(ACTIONS), replay)
            self.assertEqual(result["status"], "original_not_repeatable")
            self.assertNotIn(result["attempts"][0]["status"], ("reproduced", "pending"))

    def test_exact_fixture_and_recorded_pacing_are_preserved(self):
        for key, actual in (("fixture_sha256", "c" * 64), ("pacing_ms", 17)):
            original = tape(ACTIONS)
            original["header"].update(fixture_sha256="a" * 64, pacing_ms=0)
            def replay(actions):
                value = tape(actions)
                value["header"].update(fixture_sha256="a" * 64, pacing_ms=0)
                value["header"][key] = actual
                return value
            result = self.run_probe(original, replay)
            self.assertEqual(result["attempts"][0]["status"], "source_fixture_runtime_mismatch")

    def test_legal_outcome_cannot_accept_truncated_requested_sequence(self):
        actions = [{"id": "pause", "args": {}} for _ in range(4)]
        result = self.run_probe(tape(actions, injected=False),
                                lambda proposed: tape(proposed[:1], injected=False), target_outcome=True)
        self.assertEqual(result["status"], "original_not_repeatable")
        self.assertEqual(result["attempts"][0]["status"], "action_replay_divergence")


class OwnedProcessControls(unittest.TestCase):
    def test_actual_synthetic_exit_timeout_and_cancellation_are_distinct(self):
        with tempfile.TemporaryDirectory(prefix="goblin-process-control-") as name:
            root = Path(name)
            for tag, code, seconds, expected in (("clean", "print('synthetic')", 5, "pass"),
                    ("diagnostic", "print('ERROR: deliberate synthetic control')", 5, "diagnostic_failure"),
                    ("timeout", "import time; time.sleep(10)", 1, "timeout")):
                result = owned_process.execute([sys.executable, "-c", code], dict(os.environ),
                    root / (tag + ".log"), seconds, cwd=root, memory_limit_mib=256)
                self.assertEqual(result["status"], expected, result)
                self.assertEqual(result["surviving_owned_pids"], [])
            cancel = root / "cancel"
            cancel.write_text("synthetic request")
            result = owned_process.execute([sys.executable, "-c", "import time; time.sleep(10)"],
                dict(os.environ), root / "cancel.log", 5, cwd=root, memory_limit_mib=256, cancel_path=cancel)
            self.assertEqual(result["status"], "cancelled")
            self.assertEqual(result["surviving_owned_pids"], [])

    def test_fast_output_is_bounded_after_exit_and_readers_keep_prefix_only(self):
        with tempfile.TemporaryDirectory(prefix="goblin-fast-output-") as name:
            root = Path(name)
            log = root / "fast.log"
            with patch.object(owned_process, "MAX_LOG_BYTES", 128):
                result = owned_process.execute([sys.executable, "-c", "print('x'*4096)"],
                    dict(os.environ), log, 5, cwd=root, memory_limit_mib=256)
                prefix = owned_process.read_log_prefix(log)
            self.assertEqual(result["status"], "output_limit")
            self.assertGreater(result["log_bytes"], 128)
            self.assertEqual(result["diagnostic_prefix_bytes"], 128)
            self.assertEqual(len(prefix.encode()), 128)
            self.assertEqual(result["log_sha256"], hashlib.sha256(log.read_bytes()).hexdigest())
            self.assertEqual(result["log_bytes"], log.stat().st_size)


if __name__ == "__main__":
    unittest.main()
