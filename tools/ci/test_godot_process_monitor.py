"""Real-child regressions for the independent progress watchdog."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import godot_process_monitor as monitor
import physical_progress_watchdog as watchdog


class MonitorTests(unittest.TestCase):
    def run_child(self, program, *, name="test_physical_actor_rigs", timeout=3, capture_raises=False):
        snapshots = []
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            path = output / "child.log"
            with path.open("w") as log:
                child = subprocess.Popen([sys.executable, "-u", "-c", program], stdout=log, stderr=subprocess.STDOUT)
                try:
                    def capture(pid, _path):
                        snapshots.append((pid, child.poll()))
                        if capture_raises:
                            raise OSError("diagnostic fixture unavailable")
                    class ImmediateCapture:
                        error = None

                        def __init__(self, pid, path, _context):
                            monitor.diagnostics.snapshot(pid, path)

                        def poll(self, _now):
                            pass

                        def close(self, _reason=None):
                            pass

                    with (mock.patch.object(monitor.diagnostics, "snapshot", side_effect=capture),
                          mock.patch.object(monitor, "POLL_SECONDS", 0.01),
                          mock.patch.object(watchdog, "SNAPSHOT_IDLE_SECONDS", 0.1),
                          mock.patch.object(watchdog, "FAIL_IDLE_SECONDS", 0.2)):
                        result = monitor.wait(child, name, timeout, time.perf_counter(), path, output / "diagnostics",
                                              capture_factory=ImmediateCapture)
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.wait(timeout=5)
        return result, snapshots

    def test_stuck_engine_is_captured_alive_and_fails_before_case_deadline(self):
        result, snapshots = self.run_child('import time; print(\'CYBERSAND_PROGRESS {"phase":"step","steps":120}\'); time.sleep(10)')
        self.assertEqual(result[:2], (True, "progress_watchdog"))
        self.assertTrue(snapshots)
        self.assertIsNone(snapshots[0][1])

    def test_unrelated_output_cannot_keep_a_stuck_fixture_alive(self):
        result, _ = self.run_child('import time\nwhile True:\n print("noise"); time.sleep(0.01)')
        self.assertEqual(result[:2], (True, "progress_watchdog"))

    def test_real_progress_keeps_longer_than_idle_threshold_running(self):
        result, snapshots = self.run_child('import json,time\nfor i in range(12):\n print("CYBERSAND_PROGRESS "+json.dumps({"phase":"step","steps":i})); time.sleep(0.03)')
        self.assertEqual(result[:2], (False, None))
        self.assertEqual(snapshots, [])

    def test_other_tests_are_not_subject_to_fixture_watchdog(self):
        result, snapshots = self.run_child('import time; time.sleep(0.3)', name="unrelated_case")
        self.assertEqual(result[:2], (False, None))
        self.assertEqual(snapshots, [])

    def test_progress_cannot_extend_original_case_deadline(self):
        result, snapshots = self.run_child('import json,time\nfor i in range(100):\n print("CYBERSAND_PROGRESS "+json.dumps({"phase":"step","steps":i})); time.sleep(0.01)', timeout=0.3)
        self.assertEqual(result[:2], (True, "case_deadline"))
        self.assertTrue(snapshots)

    def test_capture_failure_is_recorded_without_losing_timeout_result(self):
        result, _ = self.run_child('import time; time.sleep(10)', capture_raises=True)
        self.assertEqual(result[:2], (True, "progress_watchdog"))
        self.assertIn("diagnostic fixture unavailable", result[2])

    def test_hung_diagnostic_process_cannot_hold_progress_watchdog(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            capture_program = output / "stuck_capture.py"
            capture_program.write_text("import time; time.sleep(30)\n")
            log_path = output / "child.log"
            with log_path.open("w") as log:
                child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], stdout=log)
                try:
                    began = time.perf_counter()
                    observed = []
                    with (mock.patch.object(monitor.diagnostics, "__file__", str(capture_program)),
                          mock.patch.object(monitor, "POLL_SECONDS", 0.01),
                          mock.patch.object(watchdog, "SNAPSHOT_IDLE_SECONDS", 0.1),
                          mock.patch.object(watchdog, "FAIL_IDLE_SECONDS", 0.2)):
                        result = monitor.wait(child, "test_physical_actor_rigs", 5, began, log_path,
                                              output / "diagnostics", on_timeout=observed.append)
                    self.assertEqual(result[:2], (True, "progress_watchdog"))
                    self.assertLess(observed[0] - began, 0.5)
                    self.assertLess(time.perf_counter() - began, 6)
                    self.assertIn("engine timeout", result[2])
                    self.assertIsNone(child.poll())
                    state = __import__("json").loads((output / "diagnostics/capture-state.json").read_text())
                    self.assertEqual(state["status"], "incomplete")
                    self.assertIsNotNone(state["returncode"])
                finally:
                    child.kill()
                    child.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
