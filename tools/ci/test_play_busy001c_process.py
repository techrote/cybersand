#!/usr/bin/env python3
"""Process custody regressions, including a zero-exit launcher leaking a child."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from play_busy001c_process import CustodyError, ProcessCustody, _Linux


def row(pid, parent, created=10, **extra):
    return {"pid": pid, "parent_pid": parent, "creation_time": created,
            "state": "S", "group": pid, "session": pid} | extra


class FakeBackend:
    def __init__(self, rows=None):
        self.rows = rows or {}
        self.terminated = []
        self.closed = False

    def table(self):
        return {pid: dict(value) for pid, value in self.rows.items()}

    def identity(self, pid):
        return self.rows.get(pid)

    def alive(self, value):
        current = self.rows.get(value["pid"])
        return (current is not None and current["creation_time"] == value["creation_time"]
                and current["state"] != "Z")

    def terminate(self, value):
        if self.alive(value):
            self.terminated.append((value["pid"], value["creation_time"]))
            del self.rows[value["pid"]]

    def reap(self, value, launcher):
        pass

    def close(self):
        self.closed = True


class CustodyTests(unittest.TestCase):
    def setup_tree(self, platform="linux"):
        backend = FakeBackend()
        custody = ProcessCustody(platform, _backend=backend)
        self.addCleanup(custody.close)
        backend.rows = {10001: row(10001, os.getpid()),
                        10002: row(10002, 10001, 11),
                        10003: row(10003, 10002, 12)}
        custody.observe(10001)
        return custody, backend

    def test_launcher_and_transitive_engine_lineage(self):
        for platform in ("linux", "windows"):
            with self.subTest(platform=platform):
                custody, _ = self.setup_tree(platform)
                observed = custody.observed_processes
                self.assertEqual(set(observed), {"10001", "10002", "10003"})
                self.assertEqual(observed["10003"]["parent_pid"], 10002)
                self.assertEqual(observed["10002"]["parent_pid"], 10001)
                self.assertEqual(observed["10001"]["creation_time"], 10)
                observed["10002"]["parent_pid"] = -1
                self.assertEqual(custody.observed_processes["10002"]["parent_pid"], 10001)

    def test_zero_exit_root_with_live_detached_child_is_not_retirement(self):
        custody, backend = self.setup_tree()
        del backend.rows[10001]
        backend.rows[10002]["parent_pid"] = os.getpid()
        # The once-observed ancestry survives parent exit/reparenting.
        self.assertEqual(set(custody.remaining()), {"10002", "10003"})
        self.assertEqual(custody.observed_processes["10002"]["parent_pid"], 10001)

    def test_cleanup_only_terminates_recorded_creation_identities(self):
        custody, backend = self.setup_tree()
        del backend.rows[10001]
        backend.rows[10002] = row(10002, 9999, 99)  # A reused, unrelated PID.
        backend.rows[20001] = row(20001, 9999, 100)
        attempted = custody.stop_remaining()
        self.assertEqual(set(attempted), {"10003"})
        self.assertEqual(backend.terminated, [(10003, 12)])
        self.assertEqual(set(backend.rows), {10002, 20001})

    def test_natural_retirement_uses_no_termination(self):
        custody, backend = self.setup_tree("windows")
        backend.rows.clear()
        self.assertEqual(custody.remaining(), {})
        self.assertEqual(backend.terminated, [])
        self.assertEqual(custody.observation_errors, [])

    def test_namespace_failure_is_not_a_clean_empty_inventory(self):
        custody, backend = self.setup_tree()
        with patch.object(backend, "table", side_effect=CustodyError("PID namespace mismatch")):
            with self.assertRaisesRegex(CustodyError, "namespace mismatch"):
                custody.remaining()
        self.assertTrue(custody.observation_errors)

    def test_actual_linux_namespace_guard(self):
        backend = object.__new__(_Linux)
        with patch.object(Path, "read_text", return_value=f"{os.getpid() + 1} (python) S 0"):
            with self.assertRaisesRegex(CustodyError, "namespace mismatch"):
                backend.table()

    def test_missing_initial_launcher_fails_closed(self):
        custody = ProcessCustody("linux", _backend=FakeBackend())
        self.addCleanup(custody.close)
        with self.assertRaisesRegex(CustodyError, "before custody"):
            custody.observe(10001)

    def test_unattributed_adopted_child_refuses_without_killing_it(self):
        custody, backend = self.setup_tree()
        backend.rows[20001] = row(20001, os.getpid(), 50)
        with self.assertRaisesRegex(CustodyError, "Unattributed"):
            custody.remaining()
        with self.assertRaisesRegex(CustodyError, "Unattributed"):
            custody.stop_remaining()
        self.assertIn(20001, backend.rows)
        self.assertNotIn((20001, 50), backend.terminated)

    def test_registered_diagnostic_subtree_is_separate_but_must_retire(self):
        custody, backend = self.setup_tree()
        backend.rows[20001] = row(20001, os.getpid(), 50)
        backend.rows[20002] = row(20002, 20001, 51)
        custody.register_auxiliary(20001)
        custody.observe(10001)
        observed = custody.observed_processes
        self.assertEqual(observed["10002"]["role"], "host")
        self.assertEqual(observed["20001"]["role"], "diagnostic")
        self.assertEqual(observed["20002"]["role"], "diagnostic")
        self.assertTrue(observed["20001"]["popen_owner"])
        for pid in [10001, 10002, 10003]:
            del backend.rows[pid]
        self.assertEqual(set(custody.remaining()), {"20001", "20002"})
        self.assertEqual(set(custody.stop_remaining()), {"20001", "20002"})
        self.assertEqual(custody.remaining(), {})

    def test_diagnostic_registration_cannot_relabel_host_or_claim_stranger(self):
        custody, backend = self.setup_tree()
        with self.assertRaisesRegex(CustodyError, "already registered"):
            custody.register_auxiliary(10002)
        backend.rows[20001] = row(20001, 9999, 50)
        with self.assertRaisesRegex(CustodyError, "direct child"):
            custody.register_auxiliary(20001)

    def test_preexisting_child_is_excluded_by_creation_not_just_pid(self):
        backend = FakeBackend({20001: row(20001, os.getpid(), 2)})
        custody = ProcessCustody("linux", _backend=backend)
        self.addCleanup(custody.close)
        backend.rows[10001] = row(10001, os.getpid(), 10)
        custody.observe(10001)
        self.assertNotIn("20001", custody.observed_processes)
        backend.rows[20001] = row(20001, os.getpid(), 20)
        with self.assertRaisesRegex(CustodyError, "Unattributed"):
            custody.remaining()

    def test_unisolated_linux_launcher_refused(self):
        backend = FakeBackend()
        custody = ProcessCustody("linux", _backend=backend)
        self.addCleanup(custody.close)
        backend.rows[10001] = row(10001, os.getpid(), group=99, session=99)
        with self.assertRaisesRegex(CustodyError, "new process session"):
            custody.observe(10001)

    def test_observer_cannot_switch_root_or_read_after_close(self):
        custody, _ = self.setup_tree()
        with self.assertRaisesRegex(CustodyError, "change its launcher"):
            custody.observe(10002)
        custody.close()
        with self.assertRaisesRegex(CustodyError, "closed"):
            custody.observe(10001)

    def test_real_zero_exit_launcher_does_not_hide_surviving_child(self):
        if not (sys.platform.startswith("linux") or sys.platform == "win32"):
            self.skipTest("Linux/Windows process custody test")
        platform = "windows" if sys.platform == "win32" else "linux"
        try:
            custody = ProcessCustody(platform)
        except CustodyError as error:
            # Development containers can expose a mismatched /proc; the actual
            # refusal is exercised above. Hosted runners must execute this case.
            if (platform == "linux" and "namespace mismatch" in str(error)
                    and os.environ.get("GITHUB_ACTIONS") != "true"):
                self.skipTest(str(error))
            raise
        self.addCleanup(custody.close)
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "child-pid.txt"
            code = (
                "import pathlib,subprocess,sys,time; "
                "p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(20)'], "
                "start_new_session=(sys.platform!='win32')); "
                "pathlib.Path(sys.argv[1]).write_text(str(p.pid)); time.sleep(0.5)"
            )
            child = subprocess.Popen([sys.executable, "-c", code, str(marker)],
                                     start_new_session=(platform == "linux"))
            try:
                custody.observe(child.pid)
                deadline = time.monotonic() + 4
                while child.poll() is None and time.monotonic() < deadline:
                    custody.observe(child.pid)
                    time.sleep(0.02)
                self.assertEqual(child.wait(timeout=2), 0)
                leaked_pid = int(marker.read_text())
                self.assertIn(str(leaked_pid), custody.remaining())
                self.assertEqual(custody.observed_processes[str(leaked_pid)]["parent_pid"], child.pid)
                attempted = custody.stop_remaining()
                self.assertIn(str(leaked_pid), attempted)
                self.assertEqual(custody.remaining(), {})
            finally:
                try:
                    custody.stop_remaining()
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.wait(timeout=2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
