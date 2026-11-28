#!/usr/bin/env python3
"""Adversarial acquisition contracts; fake Git LFS is never runtime qualification."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import materialize_lfs as subject

TIMEOUT = "batch response: Fatal error: We couldn't respond to your request in time. Sorry about that. Please try resubmitting your request and contact us if the problem persists.\n"


class Clock:
    def __init__(self):
        self.now = 0.0
    def __call__(self):
        return self.now
    def sleep(self, seconds):
        self.now += seconds


class AcquisitionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.output = self.root / "evidence"
        self.path = "native/runtime.bin"
        self.payload = b"known source-bound native fixture\x00\x01"
        target = self.root / self.path
        target.parent.mkdir()
        target.write_text("version https://git-lfs.github.com/spec/v1\noid sha256:"
                          + hashlib.sha256(self.payload).hexdigest() + "\nsize " + str(len(self.payload)) + "\n")
        self.git("init", "--quiet")
        self.git("add", self.path)
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "committed pointer")
        self.source = self.git("rev-parse", "HEAD").strip()
        self.clock = Clock()
        self.responses = []
        self.pull_count = 0
        self.success_bytes = self.payload
        self.after_success = None

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True, stderr=subprocess.STDOUT)

    def execute(self, command, root, log, seconds):
        if command[2] == "install":
            code, text, cost, timed_out = 0, "Git LFS initialized.\n", 1.0, False
        else:
            self.pull_count += 1
            code, text, cost, timed_out = self.responses.pop(0)
            if code == 0:
                (root / self.path).write_bytes(self.success_bytes)
                if self.after_success:
                    self.after_success()
        self.clock.now += cost
        log.write_text(text)
        return {"returncode": code, "timed_out": timed_out, "joined": True, "seconds": cost}

    def run_acquisition(self, allowance=100):
        return subject.materialize(self.root, [self.path], self.source, self.output, allowance,
                                   execute=self.execute, clock=self.clock, sleep=self.clock.sleep)

    def receipt(self):
        return json.loads((self.output / "receipt.json").read_text())

    def test_service_timeout_then_success_preserves_original_failure_and_exact_bytes(self):
        self.responses = [(2, TIMEOUT, 2.0, False), (0, "Downloaded exact object.\n", 1.0, False)]
        result = self.run_acquisition()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(self.pull_count, 2)
        self.assertEqual(result["backoff_seconds"], [2.0])
        self.assertEqual((self.output / "lfs-pull-1.log").read_text(), TIMEOUT)
        self.assertEqual(result["commands"][1]["returncode"], 2)
        self.assertLess(result["commands"][2]["allowance_seconds"], result["commands"][1]["allowance_seconds"])
        self.assertEqual(result["objects"][0]["actual_sha256"], hashlib.sha256(self.payload).hexdigest())
        for row in result["commands"]:
            self.assertEqual(hashlib.sha256((self.output / row["log"]).read_bytes()).hexdigest(), row["log_sha256"])

    def test_auth_and_permanent_errors_do_not_retry(self):
        for error in ("batch response: HTTP 403 forbidden", "Authentication failed", "batch response: repository not found", "unknown network failure"):
            with self.subTest(error=error):
                self.output = self.root / ("evidence-" + str(self.pull_count))
                self.responses = [(2, error, 1.0, False)]
                before = self.pull_count
                with self.assertRaisesRegex(RuntimeError, "without an admissible retry"):
                    self.run_acquisition()
                self.assertEqual(self.pull_count, before + 1)
                self.assertEqual(self.receipt()["backoff_seconds"], [])

    def test_mixed_auth_and_service_timeout_is_permanent(self):
        self.assertFalse(subject.retryable(2, TIMEOUT + "HTTP 401 Authentication failed"))
        self.assertFalse(subject.retryable(1, TIMEOUT))

    def test_three_failed_attempts_keep_all_original_logs(self):
        self.responses = [(2, TIMEOUT, 1.0, False)] * 3
        with self.assertRaisesRegex(RuntimeError, "bounded attempt limit"):
            self.run_acquisition()
        self.assertEqual(self.pull_count, 3)
        self.assertEqual(self.receipt()["backoff_seconds"], [2.0, 4.0])
        self.assertEqual(len(list(self.output.glob("lfs-pull-*.log"))), 3)
        self.assertEqual(self.receipt()["status"], "failed")

    def test_shared_deadline_refuses_another_attempt(self):
        self.responses = [(2, TIMEOUT, 88.0, False)]
        with self.assertRaises(TimeoutError):
            self.run_acquisition()
        self.assertEqual(self.pull_count, 1)
        self.assertEqual(self.receipt()["backoff_seconds"], [])
        self.assertLessEqual(self.receipt()["seconds"], 100)

    def test_process_timeout_never_retries_even_with_service_text(self):
        self.responses = [(2, TIMEOUT, 1.0, True)]
        with self.assertRaises(RuntimeError):
            self.run_acquisition()
        self.assertEqual(self.pull_count, 1)

    def test_successful_command_with_wrong_bytes_fails_without_retry(self):
        self.success_bytes = b"X" * len(self.payload)
        self.responses = [(0, "Downloaded.\n", 1.0, False)]
        with self.assertRaisesRegex(ValueError, "differs from exact committed pointer"):
            self.run_acquisition()
        self.assertEqual(self.pull_count, 1)
        self.assertEqual(self.receipt()["status"], "failed")

    def test_successful_command_with_wrong_size_fails(self):
        self.success_bytes = self.payload + b"x"
        self.responses = [(0, "Downloaded.\n", 1.0, False)]
        with self.assertRaisesRegex(ValueError, "size differs"):
            self.run_acquisition()

    def test_moved_source_cannot_be_reported_successful(self):
        def move():
            self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "--quiet", "-m", "moved")
        self.after_success = move
        self.responses = [(0, "Downloaded.\n", 1.0, False)]
        with self.assertRaisesRegex(ValueError, "source moved"):
            self.run_acquisition()

    def test_wrong_expected_source_is_refused_before_acquisition(self):
        self.source = "0" * 40
        with self.assertRaisesRegex(ValueError, "checkout differs"):
            self.run_acquisition()
        self.assertEqual(self.pull_count, 0)

    def test_nonliteral_inventory_and_previous_evidence_are_refused(self):
        for path in ("../runtime.bin", "native/*.bin", "native/runtime.bin,other", "native\\runtime.bin"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                subject.materialize(self.root, [path], self.source, self.output, 100)
        self.output.mkdir()
        (self.output / "receipt.json").write_text("original\n")
        with self.assertRaisesRegex(ValueError, "overwrite"):
            self.run_acquisition()
        self.assertEqual((self.output / "receipt.json").read_text(), "original\n")

    def test_real_fake_process_fail_once_then_success_and_hash_verification(self):
        # Genuine child processes exercise capture, natural exit and on-disk
        # object readback. This is a fake acquisition fixture, never a live LFS
        # service or native execution claim.
        fake = self.root / "fake_lfs.py"
        fake.write_text("import pathlib,sys\n"
                        "root=pathlib.Path.cwd()\n"
                        "if sys.argv[2]=='install': print('initialized');sys.exit(0)\n"
                        "state=root/'attempt-count';n=int(state.read_text())+1 if state.exists() else 1;state.write_text(str(n))\n"
                        "if n==1: print(" + repr(TIMEOUT) + ");sys.exit(2)\n"
                        "(root/" + repr(self.path) + ").write_bytes(" + repr(self.payload) + ")\n"
                        "print('exact object materialized')\n")
        def execute(command, root, log, seconds):
            return subject.run_logged([sys.executable, str(fake), *command[1:]], root, log, seconds)
        result = subject.materialize(self.root, [self.path], self.source, self.output, 60,
                                     execute=execute, sleep=lambda _: None)
        self.assertEqual(result["status"], "passed")
        self.assertEqual((self.root / "attempt-count").read_text(), "2")
        self.assertTrue(all(row["joined"] and not row["timed_out"] for row in result["commands"]))
        self.assertEqual(result["objects"][0]["actual_sha256"], hashlib.sha256((self.root / self.path).read_bytes()).hexdigest())

    def test_real_hung_process_is_retired(self):
        result = subject.run_logged([sys.executable, "-c", "import time; print('waiting',flush=True); time.sleep(30)"],
                                    self.root, self.root / "hung.log", 0.2)
        self.assertTrue(result["timed_out"])
        self.assertTrue(result["joined"])
        self.assertIsNotNone(result["returncode"])
        self.assertLess(result["seconds"], 10)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux process-tree observation")
    def test_real_hung_command_retires_its_owned_descendant(self):
        program = ("import subprocess,sys,time; "
                   "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); "
                   "print(child.pid,flush=True); time.sleep(30)")
        log = self.root / "tree.log"
        result = subject.run_logged([sys.executable, "-c", program], self.root, log, 0.2)
        self.assertTrue(result["timed_out"] and result["joined"])
        child = int(log.read_text().strip())
        # A reparented zombie has stopped executing; eventual init reaping is
        # outside this owned-tree lifecycle. No process outside this tree is killed.
        proc = Path(f"/proc/{child}/stat")
        if proc.exists():
            self.assertEqual(proc.read_text().split()[2], "Z")
        self.assertLess(result["seconds"], 10)


if __name__ == "__main__":
    unittest.main()
