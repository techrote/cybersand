#!/usr/bin/env python3
"""Ensure timeout cleanup cannot kill the 001C runner's own process group."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from run_play_busy001c_render import _spawn_render_child
from godot_timeout_diagnostics import stop_process_tree


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
