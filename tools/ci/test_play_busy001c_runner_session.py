#!/usr/bin/env python3
"""Ensure timeout cleanup cannot kill the 001C runner's own process group."""
import os
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from run_play_busy001c_render import _spawn_render_child, reported_engine_pid, parent_seconds
from godot_timeout_diagnostics import stop_process_tree


class OriginalProcessIdentityTests(unittest.TestCase):
    def test_partial_stage_write_waits_for_newline_but_final_corruption_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "original.log"
            row = {"stage": "display_ready", "process_pid": 812, "process_nonce": "a" * 32, "source_sha": "b" * 40}
            line = "PLAY_BUSY001C_PROGRESS " + json.dumps(row)
            path.write_text(line[:-4], encoding="utf-8")
            self.assertIsNone(reported_engine_pid(path, "a" * 32, "b" * 40))
            with self.assertRaises(ValueError):
                reported_engine_pid(path, "a" * 32, "b" * 40, final=True)
            path.write_text(line + "\n", encoding="utf-8")
            self.assertEqual(reported_engine_pid(path, "a" * 32, "b" * 40), 812)

    def test_completed_duplicate_or_foreign_process_identity_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "original.log"
            row = {"stage": "display_ready", "process_pid": 812, "process_nonce": "a" * 32, "source_sha": "b" * 40}
            line = "PLAY_BUSY001C_PROGRESS " + json.dumps(row) + "\n"
            path.write_text(line * 2, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicated"):
                reported_engine_pid(path, "a" * 32, "b" * 40)
            path.write_text(line, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "mismatch"):
                reported_engine_pid(path, "c" * 32, "b" * 40)

    def test_parent_reserves_cleanup_without_extending_the_case(self):
        from run_play_busy001c_render import ABSOLUTE_TIMEOUT_SECONDS, PROTOCOL_BUDGETS
        from execution_policy import godot_process_cleanup_seconds
        self.assertEqual(PROTOCOL_BUDGETS, {"absolute_seconds": 120, "progress_snapshot_seconds": 30, "progress_fail_seconds": 45})
        self.assertEqual(parent_seconds(), 120 + godot_process_cleanup_seconds())
        self.assertEqual(ABSOLUTE_TIMEOUT_SECONDS, 120)


@unittest.skipIf(sys.platform == "win32", "POSIX process-group isolation")
class PlayBusyRenderSessionTests(unittest.TestCase):
    def test_real_child_is_its_own_session_and_cleanup_returns(self):
        with tempfile.TemporaryDirectory() as tmp:
            with (Path(tmp) / "child.log").open("w") as log:
                child = _spawn_render_child(
                    [sys.executable, "-c", "import time; time.sleep(30)"], log)
                try:
                    self.assertIsNone(child.poll())
                    self.assertNotEqual(os.getpgid(child.pid), os.getpgrp())
                    self.assertEqual(os.getsid(child.pid), child.pid)
                    stop_process_tree(child)
                    self.assertIsNotNone(child.poll())
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
