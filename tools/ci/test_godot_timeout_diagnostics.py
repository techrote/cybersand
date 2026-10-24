"""Exercise failure evidence against live children, including a stuck process."""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import godot_timeout_diagnostics as diagnostics
import run_godot_regressions as runner


class DiagnosticsTests(unittest.TestCase):
    def test_last_phase_ignores_unrelated_and_truncated_output(self):
        output = ('banner\nCYBERSAND_PROGRESS {"phase":"teardown","steps":240}\n'
                  'CYBERSAND_PROGRESS {"phase":\n')
        self.assertEqual(diagnostics.last_progress(output), {"phase": "teardown", "steps": 240})
        self.assertIsNone(diagnostics.last_progress("banner only"))

    def test_timeout_capture_observes_live_child_and_preserves_failure(self):
        observed = []

        def capture(pid, path):
            # A process that has already been reaped cannot provide this result.
            observed.append(pid)
            path.mkdir()
            (path / "snapshot.json").write_text(json.dumps({"pid": pid}))

        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            command = [sys.executable, "-u", "-c",
                       'import time; print(\'CYBERSAND_PROGRESS {"phase":"step","steps":120}\'); time.sleep(10)']
            case = runner.Case("stuck", (), 0.2, 1)
            with mock.patch.object(runner, "case_command", return_value=command), mock.patch.object(diagnostics, "snapshot", side_effect=capture):
                result, failed = runner.run_case("unused", case, output, "case")
            self.assertTrue((output / "stuck-diagnostics/snapshot.json").is_file())
        self.assertTrue(observed)
        self.assertTrue(failed)
        self.assertEqual(result["status"], "timeout")
        self.assertEqual(result["timeout_seconds"], 0.2)
        self.assertEqual(result["last_progress"]["phase"], "step")
        self.assertIsNone(result["returncode"])

    def test_platform_snapshot_is_bounded_and_records_capture_outcome(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
        try:
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                diagnostics.snapshot(child.pid, output)
                result = json.loads((output / "snapshot.json").read_text())
                self.assertEqual(result["pid"], child.pid)
                self.assertTrue(result["commands"])
                self.assertIsNone(child.poll())
                if sys.platform == "win32":
                    self.assertTrue(list(output.glob("*.dmp")), (output / "minidump.txt").read_text())
        finally:
            child.kill()
            child.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
