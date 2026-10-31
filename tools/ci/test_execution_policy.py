"""Adverse execution and attribution controls for generous watchdogs."""

from contextlib import redirect_stdout
import copy
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import execution_policy as policy
import execution_telemetry as telemetry
import run_timed_command as timed


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.raw = json.loads(policy.POLICY_PATH.read_text())

    def test_owner_allowances_and_inner_outer_relationship(self):
        expected = {"main_ack_seconds": 600, "graphical_case_seconds": 1200,
                    "godot_import_seconds": 1200, "operation_seconds": 300,
                    "complex_fixture_seconds": 3600, "hosted_job_minutes": 180}
        for key, value in expected.items():
            self.assertEqual(self.raw["watchdogs"][key], value)
        self.assertGreater(policy.complex_process_seconds(), policy.watchdog_seconds("complex_fixture_seconds"))
        self.assertLess(policy.aggregate_seconds([policy.complex_process_seconds()] * 2), 180 * 60)

    def test_scale_enlarges_without_silent_shortening(self):
        with mock.patch.dict(os.environ, {policy.SCALE_ENV: "2"}):
            self.assertEqual(policy.watchdog_seconds("main_ack_seconds"), 1200)
            self.assertEqual(policy.watchdog_microseconds("operation_seconds"), 600_000_000)
        for scale in ("0", "-1", ".99", "nan", "inf", "nonsense"):
            with self.subTest(scale=scale), self.assertRaises(ValueError):
                policy.validate_policy(self.raw, scale)

    def test_invalid_missing_boolean_nonfinite_and_overflow_fail_closed(self):
        for value in (True, False, None, 0, -3, float("nan"), float("inf"), 1e30):
            changed = copy.deepcopy(self.raw)
            changed["watchdogs"]["main_ack_seconds"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                policy.validate_policy(changed)
        del self.raw["watchdogs"]["operation_seconds"]
        with self.assertRaises(ValueError):
            policy.validate_policy(self.raw)

    def test_unknown_unit_and_parent_underflow_are_not_defaults(self):
        with self.assertRaises(ValueError):
            policy.watchdog_seconds("hosted_job_minutes")
        self.raw["watchdogs"]["main_ack_seconds"] = 7200
        with self.assertRaises(ValueError):
            policy.validate_policy(self.raw)


@unittest.skipUnless(sys.platform.startswith("linux"), "Native command ownership is Linux-only; Windows uses its Job-owner controls")
class ExecutionTests(unittest.TestCase):
    def execute(self, program, timeout=3):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        output = Path(directory.name) / "attempt"
        with redirect_stdout(io.StringIO()):
            result = timed.run([sys.executable, "-u", "-c", program], timeout_seconds=timeout,
                               label="adverse-control", output_dir=output)
        self.assertTrue(result["complete"])
        self.assertEqual(result, json.loads((output / "receipt.json").read_text()))
        self.assertTrue((output / "performance.jsonl").is_file())
        return result, output

    def test_fast_success_and_exit_identity(self):
        result, output = self.execute("print('all assertions complete')")
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["natural_completion"])
        self.assertIn("all assertions complete", (output / "command.log").read_text())

    def test_correct_slow_execution_beyond_former_operation_limit(self):
        result, _ = self.execute("import time; print('slow setup'); time.sleep(16); print('complete')", timeout=30)
        self.assertEqual(result["status"], "passed")
        self.assertGreater(result["elapsed_seconds"], 15)
        self.assertTrue(result["natural_completion"])

    def test_late_assertion_remains_visible_beyond_former_operation_limit(self):
        result, output = self.execute("import time; print('setup'); time.sleep(16); assert False, 'late correctness defect'", timeout=30)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["natural_completion"])
        self.assertGreater(result["elapsed_seconds"], 15)
        self.assertIn("late correctness defect", (output / "command.log").read_text())

    def test_subprocess_failure_and_late_teardown_are_not_success(self):
        for code in (7, 19):
            result, output = self.execute(f"print('game assertions passed'); print('teardown failed'); raise SystemExit({code})")
            self.assertEqual(result["status"], "failed")
            self.assertEqual(result["returncode"], code)
            self.assertIn("teardown failed", (output / "command.log").read_text())

    def test_hung_process_keeps_partial_log_and_captured_activity(self):
        result, output = self.execute("import time; print('last successful milestone'); time.sleep(30)", timeout=0.25)
        self.assertEqual(result["status"], "timeout")
        self.assertFalse(result["natural_completion"])
        self.assertIn("last successful milestone", (output / "command.log").read_text())
        self.assertTrue((output / "approaching-watchdog.json").is_file())

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux process-session ownership control")
    def test_nested_detached_command_is_terminated_with_parent(self):
        program = "import subprocess,sys,time; p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)'],start_new_session=True); print(p.pid); time.sleep(30)"
        result, output = self.execute(program, timeout=0.4)
        self.assertEqual(result["status"], "timeout")
        child = int((output / "command.log").read_text().strip())
        self.assertIn(str(child), {str(pid) for pid in result["terminated_descendants"]})
        for _ in range(50):
            row = timed.process_table().get(child)
            if row is None or row["state"] == "Z":
                break
            time.sleep(.01)
        self.assertTrue(row is None or row["state"] == "Z")

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux surviving-child control")
    def test_zero_parent_exit_with_surviving_child_fails_teardown(self):
        result, _ = self.execute("import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); time.sleep(.15)")
        self.assertEqual(result["status"], "teardown_failed")
        self.assertEqual(result["returncode"], 0)
        self.assertFalse(result["natural_completion"])

    def test_rapid_detached_orphan_is_owned_and_cannot_pass(self):
        result, output = self.execute("import subprocess,sys; p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],start_new_session=True); print(p.pid)")
        child = int((output / "command.log").read_text().strip())
        self.assertEqual(result["status"], "teardown_failed")
        self.assertFalse(result["natural_completion"])
        self.assertIn(str(child), result["terminated_descendants"])
        row = timed.process_table().get(child)
        self.assertTrue(row is None or row["state"] == "Z")

    def test_original_attempt_cannot_be_overwritten(self):
        _, output = self.execute("print('original')")
        with self.assertRaises(FileExistsError):
            timed.run([sys.executable, "-c", "print('replacement')"], timeout_seconds=3,
                      label="adverse-control", output_dir=output)
        self.assertEqual((output / "command.log").read_text(), "original\n")


if __name__ == "__main__":
    unittest.main()
