#!/usr/bin/env python3
"""Adverse controls for launcher evidence admission; real .cmd runs need Windows."""
import json
import os
from pathlib import Path, PureWindowsPath
import sys
import tempfile
import unittest

import qualify_ultima_launcher as subject


class LauncherAdmission(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)

    def tearDown(self):
        self.directory.cleanup()

    def valid_output(self, reopened=False):
        return ("Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org\n" * 2
                + f"PAINT_EDITOR_HISTORY checks=7 failures=0 reopened={str(reopened).lower()}\n")

    def admitted(self, text, reopened=False, graphical=False):
        return subject.validate_output({"status": "passed"}, text, "4.7.stable.official.5b4e0cb0f",
                                       reopened=reopened, graphical=graphical)

    def test_two_engine_starts_and_requested_reopen_required(self):
        self.assertEqual(self.admitted(self.valid_output())["authored_workflow"]["checks"], 7)
        with self.assertRaisesRegex(ValueError, "import and runtime"):
            self.admitted(self.valid_output().split("\n", 1)[1])
        with self.assertRaisesRegex(ValueError, "author/reopen"):
            self.admitted(self.valid_output(True))

    def test_empty_failed_or_duplicate_terminal_refuses(self):
        for text in (self.valid_output().replace("checks=7", "checks=0"),
                     self.valid_output().replace("failures=0", "failures=1"),
                     self.valid_output() + "PAINT_EDITOR_HISTORY checks=1 failures=0 reopened=false\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.admitted(text)

    def test_graphical_needs_actual_renderer_record(self):
        with self.assertRaisesRegex(ValueError, "compatibility renderer"):
            self.admitted(self.valid_output(), graphical=True)
        self.assertEqual(len(self.admitted(self.valid_output() + "OpenGL API 3.3 - test\n",
                                          graphical=True)["renderer_lines"]), 1)

    def test_space_containing_cmd_has_outer_and_inner_quotes(self):
        arguments = ["--headless", "--script", subject.SCRIPT]
        # Exercise Windows spelling on every host. Native Path normalizes the
        # same input to backslashes on Windows, so a POSIX-only literal was an
        # invalid expectation there, not a defect in the shipped command.
        windows_launcher = PureWindowsPath("C:/evidence/launcher copy with spaces/Open Workbench.cmd")
        command = subject.command_line(windows_launcher, arguments, r"C:\Windows\System32\cmd.exe")
        self.assertEqual(command,
                         r'"C:\Windows\System32\cmd.exe" /d /s /c ""C:\evidence\launcher copy with spaces\Open Workbench.cmd" '
                         '--headless --script res://tests/test_paint_editor_history.gd"')
        native_launcher = Path("C:/evidence/launcher copy with spaces/Open Workbench.cmd")
        native_command = subject.command_line(native_launcher, arguments, "cmd.exe")
        self.assertIn(f'/d /s /c ""{native_launcher}" ', native_command)
        self.assertTrue(native_command.endswith('test_paint_editor_history.gd"'))
        for unsafe in ("C:/%TEMP%/Open.cmd", "C:/x&y/Open.cmd", "C:/x!y/Open.cmd"):
            with self.assertRaisesRegex(ValueError, "metacharacter"):
                subject.command_line(Path(unsafe), [], "cmd.exe")

    def create_saves(self):
        directory = self.root / "userdata/roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench"
        directory.mkdir(parents=True)
        for name in subject.SAVE_NAMES:
            setup = {"version": 2, "extent": [512, 512], "selected": 1, "actors": [{}],
                     "edits": [[1, 2, 3, 4]] * (4097 if "-dense" in name else 1)}
            value = {"version": 1, "format": "cybersand-generated-start-v1", "starting_setup": setup} \
                if "-generated" in name else setup
            (directory / name).write_text(json.dumps(value), encoding="utf-8")
        return directory

    def test_all_four_files_must_be_in_launcher_userdata(self):
        directory = self.create_saves()
        values = subject.saved_files(self.root)
        self.assertEqual(set(values), subject.SAVE_NAMES)
        target = next(directory.iterdir())
        target.rename(self.root / target.name)
        with self.assertRaisesRegex(ValueError, "four authored saves"):
            subject.saved_files(self.root)

    def test_truncated_save_and_duplicate_user_location_refuse(self):
        directory = self.create_saves()
        target = next(directory.iterdir())
        duplicate = self.root / "userdata/another" / target.name
        duplicate.parent.mkdir()
        duplicate.write_bytes(target.read_bytes())
        with self.assertRaisesRegex(ValueError, "Unexpected or redirected"):
            subject.saved_files(self.root)
        duplicate.unlink()
        target.write_bytes(b"{")
        with self.assertRaises(ValueError):
            subject.saved_files(self.root)

    @unittest.skipIf(sys.platform == "win32", "POSIX adverse process controls; actual cmd suite runs separately")
    def test_real_zero_exit_with_engine_error_refuses(self):
        record = subject.run_process([sys.executable, "-c", "print('SCRIPT ERROR: deliberate adverse control')"],
                                     self.root, os.environ.copy(), self.root / "zero-error", 3, 1, windows=False)
        self.assertEqual(record["status"], "failed")
        self.assertTrue(record["engine_error_detected"])
        self.assertGreater(record["stdout"]["bytes"], 0)

    @unittest.skipIf(sys.platform == "win32", "POSIX adverse process controls; actual cmd suite runs separately")
    def test_real_timeout_and_error_hang_are_not_natural_success(self):
        for name, source, allowance in (
                ("timeout", "import time; time.sleep(10)", 0.2),
                ("error-hang", "import time; print('ERROR: deliberate',flush=True); time.sleep(10)", 3),
                ("pause-hang", "import time; print('Press any key to continue . . .',flush=True); time.sleep(10)", 3)):
            with self.subTest(name=name):
                record = subject.run_process([sys.executable, "-c", source], self.root, os.environ.copy(),
                                             self.root / name, allowance, 1, windows=False)
                self.assertEqual(record["status"], "failed")
                self.assertTrue(record["termination_requested"])
                self.assertFalse(record["natural_completion"])

    @unittest.skipIf(sys.platform == "win32", "POSIX process control; actual cmd suite runs separately")
    def test_real_natural_zero_preserves_both_streams(self):
        record = subject.run_process([sys.executable, "-c", "import sys; print('out'); print('err',file=sys.stderr)"],
                                     self.root, os.environ.copy(), self.root / "natural", 3, 1, windows=False)
        self.assertEqual(record["status"], "passed")
        self.assertTrue(record["natural_completion"])
        self.assertEqual((self.root / "natural/stdout.log").read_text(), "out\n")
        self.assertEqual((self.root / "natural/stderr.log").read_text(), "err\n")


if __name__ == "__main__":
    unittest.main()
