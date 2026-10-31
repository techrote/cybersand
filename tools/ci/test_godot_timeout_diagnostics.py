"""Exercise failure evidence against live children, including a stuck process."""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import godot_timeout_diagnostics as diagnostics
import run_godot_regressions as runner
import godot_process_monitor as monitor


class DiagnosticsTests(unittest.TestCase):
    def test_last_phase_ignores_unrelated_and_truncated_output(self):
        output = ('banner\nCYBERSAND_PROGRESS {"phase":"teardown","steps":240}\n'
                  'CYBERSAND_PROGRESS {"phase":\n')
        self.assertEqual(diagnostics.last_progress(output), {"phase": "teardown", "steps": 240})
        self.assertIsNone(diagnostics.last_progress("banner only"))

    def test_issue233_and_legacy_markers_preserve_the_last_actual_phase(self):
        output = ('CYBERSAND_PROGRESS {"phase":"step","steps":120}\n'
                  'REGRESSION_PROGRESS case=fixture phase=roster_step rig=ripper tick=300\n')
        self.assertEqual(diagnostics.last_progress(output), {
            "case": "fixture", "phase": "roster_step", "rig": "ripper", "tick": 300,
        })

    def test_timeout_capture_observes_live_child_and_preserves_failure(self):
        observed = []

        def capture(pid, path):
            # A process that has already been reaped cannot provide this result.
            observed.append(pid)
            path.mkdir()
            (path / "snapshot.json").write_text(json.dumps({"pid": pid}))

        class ImmediateCapture:
            error = None

            def __init__(self, pid, path, _context):
                diagnostics.snapshot(pid, path)

            def poll(self, _now):
                pass

            def close(self, _reason=None):
                pass

        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            command = [sys.executable, "-u", "-c",
                       'import time; print(\'CYBERSAND_PROGRESS {"phase":"step","steps":120}\'); time.sleep(10)']
            case = runner.Case("stuck", (), 0.2, 1)
            with (mock.patch.object(runner, "case_command", return_value=command),
                  mock.patch.object(diagnostics, "snapshot", side_effect=capture),
                  mock.patch.object(monitor, "_Capture", ImmediateCapture)):
                result, failed = runner.run_case("unused", case, output, "case")
            self.assertTrue((output / "stuck-diagnostics/snapshot.json").is_file())
        self.assertTrue(observed)
        self.assertTrue(failed)
        self.assertEqual(result["status"], "timeout")
        self.assertEqual(result["timeout_seconds"], 0.2)
        self.assertEqual(result["last_progress"]["phase"], "step")
        self.assertIsNone(result["returncode"])

    def test_native_command_timeout_is_bounded_despite_descendant_output_handles(self):
        import time
        command = [sys.executable, "-u", "-c", (
            "import subprocess,sys,time;"
            "subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);"
            "print('before native timeout');time.sleep(30)"
        )]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            began = time.perf_counter()
            with mock.patch.object(diagnostics, "COMMAND_SECONDS", 0.2):
                result = diagnostics._command("stuck", command, output)
            self.assertLess(time.perf_counter() - began, 8)
            self.assertIn("TimeoutExpired", result["error"])
            self.assertIn("before native timeout", (output / "stuck.txt").read_text())

    def test_late_exited_child_remains_failed_without_live_pid_capture(self):
        child = mock.Mock(pid=4242, returncode=0)
        child.poll.return_value = 0

        def late_completion(_child, _name, timeout, started, *_paths, **options):
            options["on_timeout"](started + timeout + 0.01)
            return True, "case_deadline", None

        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            with (mock.patch.object(runner.subprocess, "Popen", return_value=child),
                  mock.patch.object(monitor, "wait", side_effect=late_completion),
                  mock.patch.object(runner, "_capture_timeout_snapshot") as capture,
                  mock.patch.object(runner.os, "killpg", create=True) as kill_group,
                  mock.patch.object(runner.time, "perf_counter", side_effect=[10.0, 10.32])):
                result, failed = runner.run_case("unused", runner.Case("late_exit", (), 0.3, 0), output, "case")
            capture.assert_not_called()
            if sys.platform != "win32":
                kill_group.assert_called_once_with(4242, signal.SIGKILL)
            child.kill.assert_not_called()
            child.wait.assert_not_called()
            self.assertTrue(failed)
            self.assertEqual(result["status"], "timeout")
            self.assertEqual(result["timeout_kind"], "case_deadline")
            self.assertIsNone(result["returncode"])
            self.assertEqual(result["timeout_observed_returncode"], 0)
            self.assertIn("already exited", result["timeout_diagnostic_skipped"])
            self.assertIn("SNAPSHOT NOT ATTEMPTED", (output / result["timeout_diagnostics"]).read_text())

    def test_termination_never_targets_an_already_exited_windows_pid(self):
        child = mock.Mock(pid=4242, returncode=0)
        child.poll.return_value = 0
        with (mock.patch.object(runner.sys, "platform", "win32"),
              mock.patch.object(runner.subprocess, "Popen") as launch):
            runner._kill_process_tree(child)
        launch.assert_not_called()
        child.kill.assert_not_called()
        child.wait.assert_not_called()

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux process-group ownership regression")
    def test_owned_group_cleanup_survives_reaped_session_leader(self):
        with tempfile.TemporaryDirectory() as directory:
            child_file = Path(directory) / "child-pid.txt"
            program = ("import subprocess,sys,pathlib;"
                       "p=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);"
                       "pathlib.Path(sys.argv[1]).write_text(str(p.pid))")
            leader = subprocess.Popen([sys.executable, "-c", program, str(child_file)], start_new_session=True)
            owned_pgid = leader.pid
            child_pid = None
            try:
                leader.wait(timeout=5)
                self.assertEqual(leader.returncode, 0)
                child_pid = int(child_file.read_text())
                self.assertEqual(os.getpgid(child_pid), owned_pgid)
                with mock.patch.object(runner.os, "getpgid", side_effect=AssertionError("retired PID lookup")):
                    runner._kill_process_tree(leader, owned_pgid=owned_pgid)
                deadline = time.monotonic() + 2
                alive = True
                while time.monotonic() < deadline:
                    status = Path(f"/proc/{child_pid}/stat")
                    if not status.exists():
                        alive = False
                        break
                    # A zombie has stopped executing and awaits its new parent's reap.
                    try:
                        child_state = status.read_text().rsplit(")", 1)[1].split()[0]
                    except FileNotFoundError:
                        alive = False
                        break
                    if child_state == "Z":
                        alive = False
                        break
                    time.sleep(0.01)
                self.assertFalse(alive, "owned descendant survived session-leader cleanup")
            finally:
                try:
                    os.killpg(owned_pgid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                if leader.poll() is None:
                    leader.kill()
                leader.wait(timeout=5)

    def test_native_command_output_is_bounded(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            result = diagnostics._command("large", [sys.executable, "-c", (
                "import sys;sys.stdout.write('o'*200000);sys.stderr.write('e'*200000)"
            )], output)
            text = (output / "large.txt").read_text()
        self.assertEqual(result["returncode"], 0)
        self.assertIn("output capped", text)
        self.assertLess(len(text), 81000)

    def test_linux_capture_retains_tree_wait_state_and_explicit_ptrace_refusal(self):
        commands = []
        def command(name, argv, output):
            commands.append((name, argv))
            (output / (name + ".txt")).write_text("ptrace: Operation not permitted")
            return {"name": name, "returncode": 1}

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with (mock.patch.object(diagnostics.sys, "platform", "linux"),
                  mock.patch.object(diagnostics.shutil, "which", side_effect=lambda name: "/usr/bin/" + name),
                  mock.patch.object(diagnostics, "_command", side_effect=command)):
                diagnostics.snapshot(123, output)
            result = json.loads((output / "snapshot.json").read_text())
            self.assertIn("Operation not permitted", (output / "stacks.txt").read_text())
        self.assertEqual(commands[0][1][:4], ["ps", "--forest", "-s", "123"])
        self.assertIn("wchan:32", commands[0][1][-1])
        self.assertEqual(commands[1][1][:4], ["ps", "-T", "-p", "123"])
        self.assertEqual(commands[2][1][:3], ["sudo", "-n", "gdb"])
        self.assertIn("ptrace refusal", result["stack_capture"])

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
