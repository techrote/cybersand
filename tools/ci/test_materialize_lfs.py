"""Acquisition negative controls; no network or credential changes."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import materialize_lfs as acquisition


class LfsAcquisition(unittest.TestCase):
    def exercise(self, responses, expected, attempts, sleeps=()):
        calls, delays = [], []
        def run(command, **kwargs):
            calls.append(command)
            value = responses.pop(0)
            if isinstance(value, Exception):
                raise value
            return subprocess.CompletedProcess(command, value[0], value[1].encode())
        with tempfile.TemporaryDirectory() as folder, contextlib.redirect_stdout(io.StringIO()):
            directory = Path(folder) / "acquisition"
            result = acquisition.materialize("godot/a.dll,godot/b.dll", directory, run=run,
                                              sleep=delays.append, clock=lambda: 0, allowance=120)
            self.assertEqual(result["status"], expected)
            self.assertEqual(len(result["attempts"]), attempts)
            self.assertEqual(delays, list(sleeps))
            self.assertEqual(json.loads((directory / "acquisition.json").read_text()), result)
            for row in [result["install"], *result["attempts"]]:
                self.assertTrue((directory / row["log"]).is_file())
            for command in calls[1:]:
                self.assertEqual(command[-2:], ["--include=godot/a.dll,godot/b.dll", "--exclude="])
        self.assertFalse(responses)

    def test_transient_then_success_preserves_both_attempts(self):
        self.exercise([(0, "installed"), (2, "Fatal error: We couldn't respond to your request in time."),
                       (0, "downloaded")], "passed", 2, [3])

    def test_three_transient_failures_remain_failed(self):
        self.exercise([(0, "installed"), *[(2, "HTTP 503 service unavailable")] * 3],
                      "failed", 3, [3, 6])

    def test_permanent_and_ambiguous_failures_do_not_retry(self):
        for text in ("HTTP 401 timed out", "HTTP 403 HTTP 503", "404 not found", "permission denied",
                     "authentication failed", "authorization failed", "unknown LFS failure"):
            with self.subTest(output=text):
                self.exercise([(0, "installed"), (2, text)], "failed", 1)

    def test_install_failure_is_not_retried(self):
        self.exercise([(1, "installation refused")], "failed", 0)

    def test_process_timeout_retains_partial_output_and_does_not_retry(self):
        self.exercise([(0, "installed"), subprocess.TimeoutExpired("git", 120, output=b"partial output")],
                      "failed", 1)

    def test_missing_git_is_a_retained_failure(self):
        self.exercise([FileNotFoundError("git unavailable")], "failed", 0)

    def test_failure_precedence(self):
        self.assertTrue(acquisition.retryable("connection reset"))
        self.assertTrue(acquisition.retryable("HTTP 429"))
        self.assertTrue(acquisition.retryable("HTTP 502"))
        self.assertTrue(acquisition.retryable("HTTP 504"))
        self.assertFalse(acquisition.retryable("HTTP 401; connection reset"))
        self.assertFalse(acquisition.retryable("repository not found; timed out"))

    def test_reuse_refuses_without_overwriting_prior_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "original"
            output.mkdir()
            original = output / "acquisition.json"
            original.write_bytes(b'{"status":"failed","unique":"prior attempt"}\n')
            before = original.read_bytes()
            def never_run(*args, **kwargs):
                self.fail("Refused evidence reuse must not invoke Git")
            with self.assertRaises(FileExistsError):
                acquisition.materialize("godot/a.dll", output, run=never_run)
            self.assertEqual(original.read_bytes(), before)
            self.assertEqual(list(output.iterdir()), [original])

    def test_empty_or_multiline_selection_refused(self):
        for include in ("", "one\ntwo", "one\rtwo"):
            with self.subTest(include=include), tempfile.TemporaryDirectory() as folder:
                with self.assertRaisesRegex(ValueError, "explicit nonempty"):
                    acquisition.materialize(include, Path(folder))


if __name__ == "__main__":
    unittest.main()
