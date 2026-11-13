"""Model-free controls for independent cancellation-descendant diagnostic."""
from pathlib import Path
import os
import signal
import subprocess
import tempfile
import time
import types
import unittest

from audit_bridge_stop_descendants import git_blob_sha, probe


class Refusal(ValueError):
    pass


def run_with_cleanup(command, log, deadline_seconds, *, cancellation_probe=None,
                     ensure_group_killed=False):
    proc = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                            stderr=subprocess.STDOUT, start_new_session=True)
    try:
        deadline = time.monotonic() + deadline_seconds
        while time.monotonic() < deadline:
            if cancellation_probe and cancellation_probe():
                raise Refusal("canceled")
            if proc.poll() is not None:
                return proc.returncode
            time.sleep(.05)
        raise Refusal("deadline")
    except BaseException:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=1)
        if ensure_group_killed:
            # Cleanup every descendant even if the immediate child exited.
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        raise


@unittest.skipIf(os.name == "nt", "POSIX-specific independent process-group fixture")
class StopProbeTests(unittest.TestCase):
    def test_finds_surviving_descendant_on_parent_only_stop(self):
        import functools
        module = types.SimpleNamespace(
            _run_owned_inference=functools.partial(run_with_cleanup, ensure_group_killed=False),
            BridgeRefusal=Refusal)
        result = probe(module, late_seconds=.5)
        self.assertTrue(result["cancel_refusal"])
        self.assertTrue(result["late_descendant_write"])
        self.assertFalse(result["stop_descendant_invariant_passed"])

    def test_accepts_strict_group_cleanup_control(self):
        import functools
        module = types.SimpleNamespace(
            _run_owned_inference=functools.partial(run_with_cleanup, ensure_group_killed=True),
            BridgeRefusal=Refusal)
        result = probe(module, late_seconds=.5)
        self.assertTrue(result["cancel_refusal"])
        self.assertFalse(result["late_descendant_write"])
        self.assertTrue(result["stop_descendant_invariant_passed"])

    def test_source_blob_identity_uses_git_blob_not_raw_sha(self):
        import hashlib
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "bytes.py"
            path.write_bytes(b"hello\n")
            self.assertEqual(git_blob_sha(path), hashlib.sha1(b"blob 6\x00hello\n").hexdigest())


if __name__ == "__main__":
    unittest.main()
