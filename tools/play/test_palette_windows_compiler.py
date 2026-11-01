#!/usr/bin/env python3
"""Portable observer/parser/ownership controls; no Windows module qualification."""
import copy
import ctypes
import json
import subprocess
import sys
import unittest
from unittest import mock

import palette_windows_compiler as observer


def observed(pid=4321):
    return {"schema": observer.SCHEMA, "requested_pid": pid, "status": "observed",
            "process": {"created_100ns": 1234567, "image_path": r"C:\engine\Godot.exe"},
            "module": {"path": r"C:\actual-angle-package\d3dcompiler_47.dll",
                       "base_address": 0x7FF000000, "file_version": "10.0.26100.1",
                       "sha256": "a" * 64, "bytes": 1048576,
                       "file_identity": {"volume_serial": 12, "file_index": 34,
                                         "last_write_100ns": 56, "bytes": 1048576}}}


class Reader:
    def __init__(self, pid, deadline):
        self.value = observed(pid)
        self.closed = False
        self.paths = []
        self.module_calls = 0
        self.process_calls = 0

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.closed = True

    def process_identity(self):
        self.process_calls += 1
        return self.value["process"].copy()

    def module(self):
        self.module_calls += 1
        return {key: self.value["module"][key] for key in ("path", "base_address")}

    def file_identity(self, path):
        self.paths.append(path)
        return {key: value for key, value in self.value["module"].items()
                if key not in ("path", "base_address")}


class ObservationTests(unittest.TestCase):
    def test_windows_sdk_structures_have_expected_fixed_sizes(self):
        self.assertEqual(ctypes.sizeof(observer.FileTime), 8)
        self.assertEqual(ctypes.sizeof(observer.FileInfo), 52)
        self.assertEqual(ctypes.sizeof(observer.VersionInfo), 52)

    def test_actual_observed_path_is_used_without_system32_guess(self):
        reader = Reader(4321, 0)
        value = observer._observe(4321, 5, lambda *_: reader)
        self.assertEqual(value, observed())
        self.assertEqual(reader.paths, [observed()["module"]["path"]])
        self.assertEqual((reader.module_calls, reader.process_calls), (2, 2))
        self.assertTrue(reader.closed)

    def test_module_change_or_process_exit_cannot_be_an_observed_identity(self):
        for field in ("module", "process_identity"):
            reader = Reader(4321, 0)
            original = getattr(reader, field)
            first = original()
            changed = dict(first, base_address=1) if field == "module" else observer.Unavailable("process exited")
            with mock.patch.object(reader, field, side_effect=[first, changed]):
                value = observer._observe(4321, 5, lambda *_: reader)
            self.assertEqual(value["status"], "unavailable")
            self.assertNotIn("module", value)
            self.assertTrue(reader.closed)

    def test_missing_module_never_hashes_a_guessed_file(self):
        reader = Reader(4321, 0)
        with mock.patch.object(reader, "module", side_effect=observer.Unavailable("not loaded")):
            value = observer._observe(4321, 5, lambda *_: reader)
        self.assertEqual(value["status"], "unavailable")
        self.assertEqual(reader.paths, [])

    def test_linux_and_invalid_pids_launch_nothing(self):
        with mock.patch.object(observer.sys, "platform", "linux"), \
                mock.patch.object(observer, "_run_bounded") as launch:
            for pid in (4321, 0, -1, True, 1.5, "4321", 2**32):
                self.assertEqual(observer.observe_loaded_compiler(pid)["status"], "unavailable")
            launch.assert_not_called()

    def test_reply_rejects_wrong_pid_unknown_digest_version_and_nonfinite(self):
        value = observed()
        self.assertEqual(observer._decode_reply(json.dumps(value).encode(), 4321), value)
        changes = [("requested_pid", True), ("requested_pid", 4322)]
        for key, replacement in changes:
            changed = copy.deepcopy(value);changed[key] = replacement
            with self.assertRaises(observer.Unavailable):
                observer._decode_reply(json.dumps(changed).encode(), 4321)
        for key, replacement in (("sha256", "unknown"), ("bytes", True), ("bytes", -1),
                                  ("file_version", "unknown"), ("path", r"C:\wrong.dll")):
            changed = copy.deepcopy(value);changed["module"][key] = replacement
            with self.subTest(key=key), self.assertRaises(observer.Unavailable):
                observer._decode_reply(json.dumps(changed).encode(), 4321)
        for bad in (b'{"x":NaN}', b'{"schema":"a","schema":"b"}'):
            with self.assertRaises(observer.Unavailable):
                observer._decode_reply(bad, 4321)

    def test_missing_policy_does_not_invent_an_observation_budget(self):
        with mock.patch.object(observer.sys, "platform", "win32"), \
                mock.patch.object(observer, "_policy_limits", side_effect=FileNotFoundError("policy missing")), \
                mock.patch.object(observer, "_run_bounded") as launch:
            value = observer.observe_loaded_compiler(4321)
        self.assertEqual(value["status"], "unavailable")
        self.assertIsNone(value["capture_seconds"])
        launch.assert_not_called()

    def test_bad_reply_retains_actual_helper_cleanup_facts(self):
        facts = {"helper_pid": 999, "helper_joined": True, "helper_returncode": 0,
                 "helper_natural_completion": True, "elapsed_seconds": .1}
        with mock.patch.object(observer.sys, "platform", "win32"), \
                mock.patch.object(observer, "_policy_limits", return_value=(30, 10, {"synthetic": True})), \
                mock.patch.object(observer, "_run_bounded", return_value=(b"not JSON", facts)):
            value = observer.observe_loaded_compiler(4321)
        self.assertEqual(value["status"], "unavailable")
        self.assertEqual(value["helper_pid"], 999)
        self.assertTrue(value["helper_joined"])
        self.assertEqual((value["capture_seconds"], value["cleanup_grace_seconds"]), (30, 10))


class HelperOwnershipTests(unittest.TestCase):
    def test_actual_short_helper_exits_naturally(self):
        output, facts = observer._run_bounded([sys.executable, "-I", "-c", "print('synthetic control')"], 5, 1)
        self.assertEqual(output.strip(), b"synthetic control")
        self.assertTrue(facts["helper_joined"])
        self.assertTrue(facts["helper_natural_completion"])
        self.assertFalse(facts["helper_terminated"])
        self.assertEqual(facts["helper_returncode"], 0)
        self.assertGreater(facts["elapsed_seconds"], 0)

    def test_actual_nonzero_helper_never_returns_observed_data(self):
        output, facts = observer._run_bounded([sys.executable, "-I", "-c", "raise SystemExit(19)"], 5, 1)
        self.assertIsNone(output)
        self.assertEqual(facts["helper_returncode"], 19)
        self.assertTrue(facts["helper_joined"])
        self.assertIn("nonzero", facts["reason"])

    def test_actual_hung_helper_is_terminated_and_observed_joined(self):
        # Explicit adverse-control budget, never the production observation policy.
        output, facts = observer._run_bounded([sys.executable, "-I", "-c", "import time; time.sleep(20)"], .03, 1)
        self.assertIsNone(output)
        self.assertTrue(facts["helper_terminated"])
        self.assertTrue(facts["helper_joined"])
        self.assertFalse(facts["helper_natural_completion"])
        self.assertNotEqual(facts["helper_returncode"], 0)
        self.assertGreaterEqual(facts["elapsed_seconds"], .03)

    def test_unobserved_join_remains_explicit_cleanup_failure(self):
        child = mock.Mock(pid=999, returncode=None)
        child.communicate.side_effect = subprocess.TimeoutExpired(["synthetic"], .01)
        child.poll.return_value = None
        output, facts = observer._run_bounded(["synthetic"], .01, .01, launch=mock.Mock(return_value=child))
        self.assertIsNone(output)
        self.assertFalse(facts["helper_joined"])
        self.assertTrue(facts["helper_terminated"])
        child.kill.assert_called_once()
        self.assertIsNone(facts["helper_returncode"])

    def test_pipe_error_still_cleans_up_only_the_owned_helper(self):
        child = mock.Mock(pid=999, returncode=-9)
        child.communicate.side_effect = [OSError("controlled pipe failure"), (b"", b"")]
        output, facts = observer._run_bounded(["synthetic"], 1, 1, launch=mock.Mock(return_value=child))
        self.assertIsNone(output)
        self.assertTrue(facts["helper_joined"])
        self.assertTrue(facts["helper_terminated"])
        child.kill.assert_called_once()
        self.assertIn("pipe failure", facts["reason"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
